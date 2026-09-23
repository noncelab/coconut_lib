// ---------------------------------------------------------------------------
// Journey of 100k Sats — Part 5
//
// Worked examples from the book 『비트코인 프로토콜 — 10만 사토시의 여정』.
// Every chapter of part 5 has a matching function below, and the numbers
// printed here are the exact numbers printed in the book.
//
//   dart run src/part_5.dart
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

// --- 등장인물 -------------------------------------------------------------

const String myMnemonic =
    'ozone drill grab fiber curtain grace pudding thank cruise elder eight picnic';
const String wifeMnemonic =
    'move advance peanut basic angle lab wall catalog absurd apart august apple';
const String recoverMnemonic =
    'calm endorse taste version suggest youth lunch caught ethics hover jungle ribbon';
const String childMnemonic =
    'public furnace safe inherit carbon scheme fashion fantasy animal enemy slender cake';

/// 2035년 1월 1일 00:00 UTC. 37장의 상속 조건이 열리는 시각이다.
const int inheritanceLocktime = 2051222400;

void main() {
  NetworkType.setNetworkType(NetworkType.mainnet);
  chapter36P2wsh();
  chapter37Taproot();
  chapter38KeyPath();
  chapter39Schnorr();
  chapter40Descriptor();
}

// --- 36장 — P2WSH ---------------------------------------------------------

/// 나와 아내의 2-of-2 P2WSH 공동 지갑에서 10만 사토시를 지출한다.
void chapter36P2wsh() {
  print('--- Chapter 36 - P2WSH ---');

  SingleSignatureVault myWallet =
      SingleSignatureVault.fromMnemonic(utf8.encode(myMnemonic));
  SingleSignatureVault wifeWallet =
      SingleSignatureVault.fromMnemonic(utf8.encode(wifeMnemonic));

  String myBsmsSigner = myWallet.getSignerBsms(AddressType.p2wsh, '나의 공동 지갑 키');
  String wifeBsmsSigner =
      wifeWallet.getSignerBsms(AddressType.p2wsh, '아내의 공동 지갑 키');

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

// --- 37~39장 — 탭루트 -----------------------------------------------------

/// 탭루트 계정에서 네 사람의 키스토어를 꺼낸다.
///
/// 37~39장이 모두 같은 네 개의 키에서 출발하므로, 각 장 함수는 이름이 겹치는
/// 지역 변수를 두는 대신 여기서 한 번에 받아 간다.
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

/// 37장에서 정한 탭트리다.
///
/// 예비키 복구를 한쪽 가지에 혼자 두고, 가족 복구와 장기 상속을 다른 쪽 가지에서
/// 한 번 더 묶는다. `{A,{B,C}}` 모양이며 이 모양이 탭 머클 루트를 결정한다.
/// 자주 쓰지 않는 조건일수록 깊은 곳에 두면 컨트롤 블록이 길어진다.
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

/// 37장의 지갑. 내부 공개키는 나 하나뿐이다.
TaprootVault scriptPathVault() {
  final keys = taprootKeyStores();
  return TaprootVault.fromTapTree([keys.me], familyTapTree(keys));
}

/// 38·39장의 가족 지갑. 내부 공개키는 나와 아내의 MuSig2 집계 공개키다.
TaprootVault familyVault() {
  final keys = taprootKeyStores();
  return TaprootVault.fromTapTree([keys.me, keys.wife], familyTapTree(keys));
}

/// 37장 — 복구와 상속 조건을 탭 트리의 스크립트 경로에 넣는다.
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

/// 38장 — 나와 아내의 공개키를 집계해 키 경로로 쓴다.
void chapter38KeyPath() {
  print('--- Chapter 38 - Key Path & MuSig2 ---');

  TaprootVault family = familyVault();
  print('Receive Address 0 : ${family.getAddress(0)}');
}

/// 39장 — 받기 0번의 88,500사토시를 받기 1번과 잔돈 0번으로 나눈다.
///
/// MuSig2의 두 왕복을 `TaprootVault.addPublicNonce`에 맡기지 않고 손으로 편다.
/// 그 편의 함수에도 `auxRand`를 넘기면 값을 고정할 수 있지만, 그러면 b와 R,
/// 도전값과 부분 서명이 모두 함수 안에 숨는다. 본문이 설명한 네 단계를 한 줄씩
/// 드러내려고 아래 단계를 직접 부른다.
void chapter39Schnorr() {
  print('--- Chapter 39 - Schnorr Signature ---');

  TaprootVault family = familyVault();
  String receiveAddress1 = family.getAddress(1);
  String changeAddress0 = family.getAddress(0, isChange: true);
  print('Receive Address 0 : ${family.getAddress(0)}');
  print('Receive Address 1 : $receiveAddress1');
  print('Change Address 0 : $changeAddress0');

  // 38장에서 가족 지갑의 받기 0번 주소로 88,500사토시를 보낸 트랜잭션이다.
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

  // 1. 서명할 메시지를 정한다.
  String sigHash = transaction.getTaprootSigHash(0, [utxo]);
  print('SigHash : $sigHash');

  Uint8List aggregatedPublicKey = family.getAggregatedPublicKey(0);
  Uint8List merkleRoot = family.getMerkleRoot(0);
  print('Aggregated Public Key : ${Codec.encodeHex(aggregatedPublicKey)}');
  print('Merkle Root : ${Codec.encodeHex(merkleRoot)}');
  print('Q : ${Codec.encodeHex(family.getOutputKey(0))}');

  // 2. 공개 논스를 교환한다.
  //
  // 보조 난수는 책의 값을 재현하기 위해 고정한다. 실제 지갑은 서명할 때마다
  // 새 난수를 써야 한다. 같은 메시지를 이 논스로 거듭 서명하면 부분 서명 식이
  // 쌓여 개인키가 드러난다.
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

  // 3. 각자 부분 서명 32바이트를 만든다.
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

  // 합치기 전에 상대의 부분 서명을 각자 검사할 수 있다.
  String myPublicKey = family.keyStoreList[0].getPublicKey(0, isXOnly: false);
  String wifePublicKey = family.keyStoreList[1].getPublicKey(0, isXOnly: false);
  print('My Partial Signature Valid? : '
      '${Ecc.verifyMuSig2PartialSignature(myPartialSignature, myPublicNonce, Codec.decodeHex(myPublicKey), session)}');
  print('Wife Partial Signature Valid? : '
      '${Ecc.verifyMuSig2PartialSignature(wifePartialSignature, wifePublicNonce, Codec.decodeHex(wifePublicKey), session)}');

  // 4. 두 부분 서명을 더해 64바이트 슈노르 서명 하나로 만든다.
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

// --- 40장 — 미니스크립트와 BSMS -------------------------------------------

/// 40장 — 가족 지갑의 설계도를 디스크립터와 BSMS로 남긴다.
///
/// 디스크립터는 받기 가지와 잔돈 가지를 따로 만든다. BSMS는 각 서명 장치가
/// 자기 xpub을 담아 보내는 키 레코드와, 조정자가 정책을 결합해 돌려주는
/// 디스크립터 레코드로 이루어진다.
void chapter40Descriptor() {
  print('--- Chapter 40 - Miniscript & BSMS ---');

  TaprootVault family = familyVault();
  print('Descriptor : ${family.descriptor}');

  // 각 장치가 보내는 BSMS 키 레코드. 한 사람이 장치를 여럿 가질 수 있으므로
  // 나의 주 키와 예비키는 서로 다른 서명자로 센다.
  final keys = taprootKeyStores();
  for (final signer in [
    ('나의 주 키 장치', myMnemonic),
    ('나의 예비키 장치', recoverMnemonic),
    ('아내의 서명 장치', wifeMnemonic),
    ('아이의 서명 장치', childMnemonic),
  ]) {
    TaprootVault vault = TaprootVault.fromSeedList(
        [Seed.fromMnemonic(utf8.encode(signer.$2))], []);
    print('--- Signer BSMS : ${signer.$1}');
    print(vault.getSignerBsms(signer.$1));
  }

  // 조정자가 네 키 레코드를 정책과 결합해 돌려주는 디스크립터 레코드.
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

/// 고정된 보조 난수로 BIP 327의 97바이트 비밀 논스를 만든다.
///
/// `KeyStore.getPublicNonce`는 보조 난수를 `Random.secure()`로 만들고 결과를
/// 내부 맵에 감춰 두지만, 그 아래의 `calculateSecretNonce`는 난수를 인자로 받는다.
/// 책의 값을 재현하려면 이쪽을 직접 부른다.
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

/// 두 사람의 66바이트 공개 논스를 자리끼리 더한다.
///
/// 앞 33바이트끼리 더해 R₁을, 뒤 33바이트끼리 더해 R₂를 만든다.
Uint8List aggregatePublicNonce(Uint8List first, Uint8List second) {
  Uint8List combine(int from, int to) => Ecc.pointCombine(
      first.sublist(from, to), second.sublist(from, to), true)!;
  return Uint8List.fromList([...combine(0, 33), ...combine(33, 66)]);
}

/// 공개키를 사전순으로 비교한다. MuSig2는 집계 전에 키를 정렬한다.
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
