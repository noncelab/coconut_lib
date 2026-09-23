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
  // chapter36P2wsh();
  // chapter37Taproot();
  // chapter38KeyPath();
  chapter39Schnorr();
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

/// 37장에서 정한 세 가지 스크립트 경로 조건이다.
///
/// 예비키 단독 복구, 아이와 아내의 공동 복구, 2035년 이후 아이의 상속 순으로
/// 탭 트리에 들어간다.
List<Policy> familyPolicies(
    ({KeyStore me, KeyStore wife, KeyStore recover, KeyStore child}) keys) {
  return [
    SingleSignaturePolicy(keys.recover),
    MultisignaturePolicy([keys.child, keys.wife], 2),
    InheritancePolicy(keys.child, inheritanceLocktime),
  ];
}

/// 37장의 지갑. 내부 공개키는 나 하나뿐이다.
TaprootVault scriptPathVault() {
  final keys = taprootKeyStores();
  return TaprootVault.fromKeyStoreList([keys.me], familyPolicies(keys));
}

/// 38·39장의 가족 지갑. 내부 공개키는 나와 아내의 MuSig2 집계 공개키다.
TaprootVault familyVault() {
  final keys = taprootKeyStores();
  return TaprootVault.fromKeyStoreList(
      [keys.me, keys.wife], familyPolicies(keys));
}

/// 37장 — 복구와 상속 조건을 탭 트리의 스크립트 경로에 넣는다.
void chapter37Taproot() {
  print('--- Chapter 37 - Taproot ---');

  final keys = taprootKeyStores();
  print('My xpub : ${keys.me.extendedPublicKey}');
  print('Wife xpub : ${keys.wife.extendedPublicKey}');
  print('Recover xpub : ${keys.recover.extendedPublicKey}');
  print('Child xpub : ${keys.child.extendedPublicKey}');

  List<Policy> policies = familyPolicies(keys);
  print('Recover policy : ${policies[0].toScript(0).serialize()}');
  print('Multisig policy : ${policies[1].toScript(0).serialize()}');
  print('Inheritance policy : ${policies[2].toScript(0).serialize()}');

  print('Receive Address 0 : ${scriptPathVault().getAddress(0)}');
}

/// 38장 — 나와 아내의 공개키를 집계해 키 경로로 쓴다.
void chapter38KeyPath() {
  print('--- Chapter 38 - Key Path & MuSig2 ---');

  TaprootVault family = familyVault();
  print('Receive Address 0 : ${family.getAddress(0)}');
}

/// 39장 — 받기 0번의 88,500사토시를 받기 1번과 잔돈 0번으로 나눈다.
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

  String sigHash = transaction.getTaprootSigHash(0, [utxo]);
  print("SigHash : $sigHash");
  String myNonce = family.keyStoreList[0].getPublicNonce(
      sigHash, Codec.encodeHex(family.getAggregatedPublicKey(0)), 0, false);
  String wifeNonce = family.keyStoreList[1].getPublicNonce(
      sigHash, Codec.encodeHex(family.getAggregatedPublicKey(0)), 0, false);

  print("Q : ${Codec.encodeHex(family.getOutputKey(0))}");

  print("My Public Nonce : $myNonce");
  print("Wife Public Nonce : $wifeNonce");
}
