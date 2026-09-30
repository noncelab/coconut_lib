// ---------------------------------------------------------------------------
// Journey of 100k Sats — Part 5
//
// Worked examples from the book Bitcoin Protocol — The Journey of 100,000
// Satoshis. Every chapter of part 5 has a matching function below, and the numbers
// printed here are the exact numbers printed in the book.
//
//   dart run doc/bitcoin_protocol_book/part_5.dart
//
// Each chapter function is self-contained: it rebuilds the wallets it needs
// from the mnemonics below instead of sharing local variables with its
// neighbours. Deriving a wallet twice is cheap, and it keeps one chapter from
// quietly depending on a name another chapter happened to define.
//
// WARNING
// Every secret in this file is published in a book. Anyone holding a copy can
// derive the private keys. Never send real bitcoin to an address derived from
// these values.
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';

// --- The cast ---------------------------------------------------------------

const String myMnemonic =
    'ozone drill grab fiber curtain grace pudding thank cruise elder eight picnic';
const String wifeMnemonic =
    'move advance peanut basic angle lab wall catalog absurd apart august apple';
const String recoverMnemonic =
    'calm endorse taste version suggest youth lunch caught ethics hover jungle ribbon';
const String childMnemonic =
    'public furnace safe inherit carbon scheme fashion fantasy animal enemy slender cake';

/// 2035-01-01 00:00 UTC, the moment chapter 37's inheritance branch opens.
const int inheritanceLocktime = 2051222400;

void main() {
  NetworkType.setNetworkType(NetworkType.mainnet);
  chapter36P2wsh();
  chapter37Taproot();
  chapter38KeyPath();
  chapter39Schnorr();
  chapter40Descriptor();
}

// --- Chapter 36 — P2WSH -------------------------------------------------------

/// Spends 100,000 sats from the 2-of-2 P2WSH wallet I share with my wife.
void chapter36P2wsh() {
  print('--- Chapter 36 - P2WSH ---');

  SingleSignatureVault myWallet =
      SingleSignatureVault.fromMnemonic(utf8.encode(myMnemonic));
  SingleSignatureVault wifeWallet =
      SingleSignatureVault.fromMnemonic(utf8.encode(wifeMnemonic));

  String myBsmsSigner =
      myWallet.getSignerBsms(AddressType.p2wsh, 'My shared wallet key');
  String wifeBsmsSigner = wifeWallet.getSignerBsms(
      AddressType.p2wsh, "My wife's shared wallet key");

  MultisignatureVault p2wshWallet = MultisignatureVault.fromKeyStoreList([
    KeyStore.fromSignerBsms(myBsmsSigner),
    KeyStore.fromSignerBsms(wifeBsmsSigner)
  ], 2, addressType: AddressType.p2wsh);

  p2wshWallet.bindSeedToKeyStore(myWallet.keyStore.seed);
  p2wshWallet.bindSeedToKeyStore(wifeWallet.keyStore.seed);

  TransactionOutput utxo = TransactionOutput.forPayment(
      100000, 'bc1qm3jugz2ugjd4leuxvm3tk32w5khs763pzhew26fgfvl2xcxrs7sqg7flqc');

  Transaction transaction = Transaction.withInputsAndOutputs([
    TransactionInput.forPayment(
        '274a01d89c76ea523b0f41c9d816a2475eb9c3801a24f7d6e085139b2a7c4d6f', 0,
        sequence: 0xfffffffd)
  ], [
    TransactionOutput.forPayment(10000, wifeWallet.getAddress(0)),
    TransactionOutput.forPayment(
        89000, p2wshWallet.getAddress(0, isChange: true))
  ], AddressType.p2wsh);

  Uint8List myPublicKey = p2wshWallet.keyStoreList[0].getPublicKeyBytes(0);
  Uint8List wifePublicKey = p2wshWallet.keyStoreList[1].getPublicKeyBytes(0);

  Script witnessScript =
      MultisignatureScript.forP2wsh(2, 2, [myPublicKey, wifePublicKey]);

  String sigHash = transaction.getSigHash(0, utxo, AddressType.p2wsh,
      witnessScript: witnessScript.rawSerialize());
  Uint8List mySignature = p2wshWallet.keyStoreList[0]
      .getChildHdWallet(false)
      .derive(0)
      .signEcdsa(Codec.decodeHex(sigHash));
  Uint8List wifeSignature = p2wshWallet.keyStoreList[1]
      .getChildHdWallet(false)
      .derive(0)
      .signEcdsa(Codec.decodeHex(sigHash));

  transaction.inputs[0].setSignature(
      AddressType.p2wsh,
      [
        Signature(Codec.encodeHex(mySignature), Codec.encodeHex(myPublicKey)),
        Signature(
            Codec.encodeHex(wifeSignature), Codec.encodeHex(wifePublicKey))
      ],
      witnessScript:
          MultisignatureScript.forP2wsh(2, 2, [myPublicKey, wifePublicKey]));

  print('P2WSH Raw Transaction : ${transaction.serialize()}');
  print('TXID : ${transaction.transactionHash}');
  print('Valid Signature? : ${transaction.validateEcdsa(0, utxo)}');
}

// --- Chapters 37-39 — Taproot -------------------------------------------------

/// The four key stores of the Taproot account.
///
/// Chapters 37 to 39 all start from these same four keys, so each chapter takes
/// them from here instead of keeping its own local variables.
({KeyStore me, KeyStore wife, KeyStore recover, KeyStore child})
    taprootKeyStores() {
  KeyStore keyStoreOf(String mnemonic) =>
      TaprootVault.fromSeedList([Seed.fromMnemonic(utf8.encode(mnemonic))], [])
          .keyStoreList[0];

  return (
    me: keyStoreOf(myMnemonic),
    wife: keyStoreOf(wifeMnemonic),
    recover: keyStoreOf(recoverMnemonic),
    child: keyStoreOf(childMnemonic),
  );
}

/// The tap tree chapter 37 settles on.
///
/// Backup recovery sits alone on one branch; family recovery and the long
/// inheritance share the other. The shape is `{A,{B,C}}`, and the shape decides
/// the tap merkle root. A leaf placed deeper carries a longer control block, so
/// the rarely used conditions are the ones put out of the way.
TapTree familyTapTree(
    ({KeyStore me, KeyStore wife, KeyStore recover, KeyStore child}) keys) {
  return TapBranch(
    TapLeaf(SingleSignaturePolicy(keys.recover)),
    TapBranch(
      TapLeaf(MultisignaturePolicy([keys.child, keys.wife], 2)),
      TapLeaf(InheritancePolicy(keys.child, inheritanceLocktime)),
    ),
  );
}

/// Chapter 37's wallet. The internal key is mine alone.
TaprootVault scriptPathVault() {
  final keys = taprootKeyStores();
  return TaprootVault.fromTapTree([keys.me], familyTapTree(keys));
}

/// The family wallet of chapters 38 and 39. The internal key is the MuSig2
/// aggregate of my key and my wife's.
TaprootVault familyVault() {
  final keys = taprootKeyStores();
  return TaprootVault.fromTapTree([keys.me, keys.wife], familyTapTree(keys));
}

/// Chapter 37 — puts the recovery and inheritance conditions on the tap tree's
/// script paths.
void chapter37Taproot() {
  print('--- Chapter 37 - Taproot ---');

  final keys = taprootKeyStores();
  print('My xpub : ${keys.me.extendedPublicKey}');
  print('Wife xpub : ${keys.wife.extendedPublicKey}');
  print('Recover xpub : ${keys.recover.extendedPublicKey}');
  print('Child xpub : ${keys.child.extendedPublicKey}');

  TapTree tree = familyTapTree(keys);
  List<Policy> leaves = tree.leaves;
  print('Recover policy : ${leaves[0].toScript(0).serialize()}');
  print('Multisig policy : ${leaves[1].toScript(0).serialize()}');
  print('Inheritance policy : ${leaves[2].toScript(0).serialize()}');
  print('Tree expression : ${tree.toTreeExpression()}');
  print('Merkle Root : ${Codec.encodeHex(tree.getMerkleRoot(0))}');

  print('Receive Address 0 : ${scriptPathVault().getAddress(0)}');
}

/// Chapter 38 — aggregates my public key with my wife's and spends the key path.
void chapter38KeyPath() {
  print('--- Chapter 38 - Key Path & MuSig2 ---');

  TaprootVault family = familyVault();
  print('Receive Address 0 : ${family.getAddress(0)}');
}

/// Chapter 39 — splits the 88,500 sats on receive 0 between receive 1 and
/// change 0.
///
/// MuSig2's two rounds are unrolled by hand rather than left to
/// `TaprootVault.addPublicNonce`. That convenience method takes an `auxRand`
/// too, so the values could be pinned through it, but then b and R, the
/// challenge and the partial signatures all stay hidden inside it. The four
/// steps the book walks through are called out one by one below.
void chapter39Schnorr() {
  print('--- Chapter 39 - Schnorr Signature ---');

  TaprootVault family = familyVault();
  String receiveAddress1 = family.getAddress(1);
  String changeAddress0 = family.getAddress(0, isChange: true);
  print('Receive Address 0 : ${family.getAddress(0)}');
  print('Receive Address 1 : $receiveAddress1');
  print('Change Address 0 : $changeAddress0');

  // The chapter 38 transaction that paid 88,500 sats to the family wallet's
  // receive address 0.
  const String previousTxId =
      '886f3585b614c2b1fede845e60d63f802d94897467956ae825ab9fe7f166b5c6';

  TransactionOutput utxo =
      TransactionOutput.forPayment(88500, family.getAddress(0));

  Transaction transaction = Transaction.withInputsAndOutputs([
    TransactionInput.forPayment(previousTxId, 0, sequence: 0xfffffffd)
  ], [
    TransactionOutput.forPayment(10000, receiveAddress1),
    TransactionOutput.forPayment(78000, changeAddress0)
  ], AddressType.p2tr);

  print('Unsigned Transaction : ${transaction.serialize()}');
  print('TXID : ${transaction.transactionHash}');

  // 1. Settle on the message to sign.
  String sigHash = transaction.getTaprootSigHash(0, [utxo]);
  print('SigHash : $sigHash');

  Uint8List aggregatedPublicKey = family.getAggregatedPublicKey(0);
  Uint8List merkleRoot = family.getMerkleRoot(0);
  print('Aggregated Public Key : ${Codec.encodeHex(aggregatedPublicKey)}');
  print('Merkle Root : ${Codec.encodeHex(merkleRoot)}');
  print('Q : ${Codec.encodeHex(family.getOutputKey(0))}');

  // 2. Exchange the public nonces.
  //
  // The auxiliary randomness is pinned so the book's values come out again. A
  // real wallet draws fresh randomness for every signature: signing more than
  // once with the same nonce stacks up partial-signature equations until the
  // private key falls out.
  Uint8List myNonce = musig2SecretNonce(
      family.keyStoreList[0], 'book: my nonce', aggregatedPublicKey, sigHash);
  Uint8List wifeNonce = musig2SecretNonce(
      family.keyStoreList[1], 'book: wife nonce', aggregatedPublicKey, sigHash);

  Uint8List myPublicNonce = KeyStore.calculatePublicNonce(myNonce);
  Uint8List wifePublicNonce = KeyStore.calculatePublicNonce(wifeNonce);
  print('My Public Nonce : ${Codec.encodeHex(myPublicNonce)}');
  print('Wife Public Nonce : ${Codec.encodeHex(wifePublicNonce)}');

  Uint8List aggregatedNonce =
      aggregatePublicNonce(myPublicNonce, wifePublicNonce);
  print('Aggregated Nonce : ${Codec.encodeHex(aggregatedNonce)}');

  List<Uint8List> publicKeyList = [
    Codec.decodeHex(family.keyStoreList[0].getPublicKey(0, isXOnly: false)),
    Codec.decodeHex(family.keyStoreList[1].getPublicKey(0, isXOnly: false))
  ]..sort(compareBytes);

  SessionContext session = SessionContext(publicKeyList, aggregatedNonce,
      aggregatedPublicKey, Codec.decodeHex(sigHash),
      merkleRoot: merkleRoot);

  // 3. Each side produces its 32-byte partial signature.
  Uint8List myPartialSignature = Ecc.signSchnorrForMuSig2(
      myNonce,
      Codec.decodeHex(family.keyStoreList[0].getPrivateKey(0, isXOnly: false)),
      session,
      isFullSignature: false);
  Uint8List wifePartialSignature = Ecc.signSchnorrForMuSig2(
      wifeNonce,
      Codec.decodeHex(family.keyStoreList[1].getPrivateKey(0, isXOnly: false)),
      session,
      isFullSignature: false);
  print('My Partial Signature : ${Codec.encodeHex(myPartialSignature)}');
  print('Wife Partial Signature : ${Codec.encodeHex(wifePartialSignature)}');

  // Before combining, each side can check the other's partial signature.
  String myPublicKey = family.keyStoreList[0].getPublicKey(0, isXOnly: false);
  String wifePublicKey = family.keyStoreList[1].getPublicKey(0, isXOnly: false);
  print('My Partial Signature Valid? : '
      '${Ecc.verifyMuSig2PartialSignature(myPartialSignature, myPublicNonce, Codec.decodeHex(myPublicKey), session)}');
  print('Wife Partial Signature Valid? : '
      '${Ecc.verifyMuSig2PartialSignature(wifePartialSignature, wifePublicNonce, Codec.decodeHex(wifePublicKey), session)}');

  // 4. Add the two partial signatures into one 64-byte Schnorr signature.
  Uint8List signature = Ecc.getAggregatedSignatureForMuSig2(session, [
    Signature(Codec.encodeHex(myPartialSignature), myPublicKey),
    Signature(Codec.encodeHex(wifePartialSignature), wifePublicKey)
  ]);
  print('Schnorr Signature : ${Codec.encodeHex(signature)}');
  print('  r : ${Codec.encodeHex(signature.sublist(0, 32))}');
  print('  s : ${Codec.encodeHex(signature.sublist(32, 64))}');

  transaction.inputs[0]
      .setTaprootKeyPathSpendingSignature(Codec.encodeHex(signature));
  print('Raw Transaction : ${transaction.serialize()}');
  print('Valid Signature? : '
      '${Ecc.verifySchnorr(Codec.decodeHex(sigHash), family.getOutputKey(0), signature)}');
}

// --- Chapter 40 — Miniscript and BSMS -------------------------------------------

/// Chapter 40 — writes the family wallet's blueprint down as a descriptor and
/// as BSMS records.
///
/// The descriptor covers the receive branch and the change branch. BSMS has two
/// halves: a key record each signing device sends with its own xpub, and the
/// descriptor record the coordinator sends back once it has combined them with
/// the policy.
void chapter40Descriptor() {
  print('--- Chapter 40 - Miniscript & BSMS ---');

  TaprootVault family = familyVault();
  print('Descriptor : ${family.descriptor}');

  // The key record each device sends. One person can hold several devices, so
  // my main key and my backup key count as separate signers.
  final keys = taprootKeyStores();
  for (final signer in [
    ('My main key device', myMnemonic),
    ('My backup key device', recoverMnemonic),
    ("My wife's signing device", wifeMnemonic),
    ("My child's signing device", childMnemonic),
  ]) {
    TaprootVault vault = TaprootVault.fromSeedList(
        [Seed.fromMnemonic(utf8.encode(signer.$2))], []);
    print('--- Signer BSMS : ${signer.$1}');
    print(vault.getSignerBsms(signer.$1));
  }

  // The descriptor record the coordinator returns, the four key records
  // combined with the policy.
  print('--- Coordinator BSMS');
  print(family.getCoordinatorBsms());

  print('Master Fingerprints : '
      '${[
    keys.me,
    keys.recover,
    keys.wife,
    keys.child
  ].map((k) => k.masterFingerprint).join(", ")}');
}

/// Builds BIP-327's 97-byte secret nonce from pinned auxiliary randomness.
///
/// `KeyStore.getPublicNonce` draws that randomness with `Random.secure()` and
/// keeps the result in an internal map, but `calculateSecretNonce` underneath
/// takes it as an argument. Reproducing the book's values calls that directly.
Uint8List musig2SecretNonce(KeyStore keyStore, String label,
    Uint8List aggregatedPublicKey, String sigHash) {
  return KeyStore.calculateSecretNonce(
      Hash.sha256fromByte(utf8.encode(label)),
      Codec.decodeHex(keyStore.getPrivateKey(0, isXOnly: false)),
      Codec.decodeHex(keyStore.getPublicKey(0, isXOnly: false)),
      aggregatedPublicKey,
      Codec.decodeHex(sigHash),
      null);
}

/// Adds two 66-byte public nonces half by half.
///
/// The leading 33 bytes combine into R₁, the trailing 33 into R₂.
Uint8List aggregatePublicNonce(Uint8List first, Uint8List second) {
  Uint8List combine(int from, int to) => Ecc.pointCombine(
      first.sublist(from, to), second.sublist(from, to), true)!;
  return Uint8List.fromList([...combine(0, 33), ...combine(33, 66)]);
}

/// Compares public keys lexicographically. MuSig2 sorts the keys before it
/// aggregates them.
int compareBytes(Uint8List a, Uint8List b) {
  for (int i = 0; i < a.length && i < b.length; i++) {
    if (a[i] != b[i]) return a[i] - b[i];
  }
  return a.length - b.length;
}

//tr(
//    musig(
//      [A07D432C/86'/0'/0']xpub6BosKTRL8fh9rBAzdQebnBUnhXNHjYkTrRCna3ajTTx1S7Pw4BvtcrecxNqqxVY4xfCEcGNdq6upmCUYaPahvYsYsDd4ikAHTHK739L6794/<0;1>/*,
//      [C55DC47B/86'/0'/0']xpub6C8TGAeFXCL3ffDPJ2Ccr6VuxDcxkodEDRnmdQBbCm5UB89zdWVPUkuJH6Fj7an4Fo1BMKPZEJwUecwA4axeBpNbgxJo8thUEKqU8hfdtAi/<0;1>/*
//    ),
//    {pk([BDCE09C9/86'/0'/0']xpub6Cnp4SUHXwNJLcPCbB1jARRba9xA9SQ3tHJzbX9rwMqkfKq8aQYo71TAxYDgecygFLZXTWqr88o9zLE6KuWsCyouFJUVP74y3dyXVwxenX8/<0;1>/*),
//      {multi_a(2,[632C9182/86'/0'/0']xpub6BgV5tckhh4dbYYYrDFnU4MHnnFBuD78NnwJefzozuBbjXwDXPVKsULAeQ68cbUhPLVX1fZcKfHPLLRyP1QiyWmA5uKF2r8PQgoohYgcQgP/<0;1>/*,
//                 [C55DC47B/86'/0'/0']xpub6C8TGAeFXCL3ffDPJ2Ccr6VuxDcxkodEDRnmdQBbCm5UB89zdWVPUkuJH6Fj7an4Fo1BMKPZEJwUecwA4axeBpNbgxJo8thUEKqU8hfdtAi/<0;1>/*),
//       and_v(v:after(2051222400),pk([632C9182/86'/0'/0']xpub6BgV5tckhh4dbYYYrDFnU4MHnnFBuD78NnwJefzozuBbjXwDXPVKsULAeQ68cbUhPLVX1fZcKfHPLLRyP1QiyWmA5uKF2r8PQgoohYgcQgP/<0;1>/*))
//      }
//    }
// )#pfl8undv/0/*,/1/*
