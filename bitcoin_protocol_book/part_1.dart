// ---------------------------------------------------------------------------
// Journey of 100k Sats — Part 1
//
// Worked examples from the book Bitcoin Protocol — The Journey of 100,000
// Satoshis. Every chapter of part 1 has a matching function below, and the
// numbers printed here are the exact numbers printed in the book.
//
//   dart run src/part_1.dart
//
// Each chapter function is self-contained: it rebuilds what it needs from the
// coin flips below instead of sharing local variables with its neighbours.
// Deriving a wallet twice is cheap, and it keeps one chapter from quietly
// depending on a name another chapter happened to define.
//
// WARNING
// Every secret in this file is published in a book. Anyone holding a copy can
// derive the private keys. Never send real bitcoin to an address derived from
// these values.
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';

// --- Where the journey starts ----------------------------------------------

/// The 128 coin flips of chapter 1, heads as 1 and tails as 0.
const String entropyBits =
    '1001111010001000010111011001010100101010110100110110001011001010'
    '1110101101001110111111100011010010101000111010010001101111010010';

/// The passphrase added on top of the mnemonic in chapter 2.
const String passphrase = 'coffee with alex at seven';

// --- What the transaction of chapter 13 spends and pays ---------------------

const String friendAddress = 'bc1qng0nk3xgye50vkjsc448cuu335s7xa4lnnx0sy';
const String previousTxId =
    '13b394e8f3f13757392c827aac46802bc4a17be3285a8035bc5d91758fbfe1c6';
const int previousOutputIndex = 0;
const int sequence = 0xfffffffd;
const int spentAmount = 100000;
const int sendingAmount = 10000;
const int changeAmount = 89000;

void main() {
  NetworkType.setNetworkType(NetworkType.mainnet);
  chapter1Mnemonic();
  chapter2Seed();
  chapter3HdWallet();
  chapter9ExtendedPublicKey();
  chapter10Address();
  chapter13Transaction();
  chapter15Signature();
}

// --- Pieces the chapters share ----------------------------------------------

/// The mnemonic the coin flips of chapter 1 produce.
Uint8List myMnemonic() =>
    Seed.fromEntropy(Converter.binToBytes(entropyBits)).mnemonic;

/// The root seed of chapter 2: the mnemonic stretched with the passphrase.
Seed mySeed() =>
    Seed.fromMnemonic(myMnemonic(), passphrase: utf8.encode(passphrase));

/// The single signature wallet the whole journey spends from.
SingleSignatureVault myWallet() => SingleSignatureVault.fromKeyStore(
    KeyStore.fromSeed(mySeed(), AddressType.p2wpkh));

/// The 100,000 sats sitting on receive address 0, waiting to be spent.
TransactionOutput spentUtxo() =>
    TransactionOutput.forPayment(spentAmount, myWallet().getAddress(0));

/// The chapter 13 transaction, before any signature goes in.
Transaction unsignedTransaction() {
  SingleSignatureVault wallet = myWallet();
  return Transaction.withInputsAndOutputs([
    TransactionInput.forPayment(previousTxId, previousOutputIndex,
        sequence: sequence)
  ], [
    TransactionOutput.forPayment(sendingAmount, friendAddress),
    TransactionOutput.forPayment(
        changeAmount, wallet.getAddress(0, isChange: true))
  ], AddressType.p2wpkh);
}

// --- Chapter 1 — Entropy and the mnemonic -----------------------------------

/// Turns 128 coin flips into the twelve words that stand for them.
void chapter1Mnemonic() {
  print('--- Chapter 1 - Entropy and the mnemonic ---');

  Uint8List hexEntropy = Converter.binToBytes(entropyBits);
  print('Entropy Bits : $entropyBits');
  print('Hex Entropy : ${Codec.encodeHex(hexEntropy)}');
  print('Mnemonic : ${utf8.decode(Seed.fromEntropy(hexEntropy).mnemonic)}');
}

// --- Chapter 2 — Seed --------------------------------------------------------

/// Stretches the twelve words and the passphrase into a 64-byte root seed.
void chapter2Seed() {
  print('--- Chapter 2 - Seed ---');

  print('Seed : ${Codec.encodeHex(mySeed().rootSeed)}');
}

// --- Chapter 3 — HD wallet ---------------------------------------------------

/// Grows the first two receive keys out of the one seed.
void chapter3HdWallet() {
  print('--- Chapter 3 - HD wallet ---');

  KeyStore keyStore = KeyStore.fromSeed(mySeed(), AddressType.p2wpkh);
  print('Receive Private Key 0 : ${keyStore.getPrivateKey(0)}');
  print('Receive Private Key 1 : ${keyStore.getPrivateKey(1)}');
}

// --- Chapter 9 — Extended public key -----------------------------------------

/// The account xpub and the descriptor that says how to use it.
void chapter9ExtendedPublicKey() {
  print('--- Chapter 9 - Extended public key ---');

  SingleSignatureVault wallet = myWallet();
  print('xPub : ${wallet.keyStore.extendedPublicKey.serialize()}');
  print('Descriptor : ${wallet.descriptor}');
}

// --- Chapter 10 — Address ----------------------------------------------------

/// The first receive address, the one the 100,000 sats arrive at.
void chapter10Address() {
  print('--- Chapter 10 - Address ---');

  print('Receive Address 0 : ${myWallet().getAddress(0)}');
}

// --- Chapter 13 — Transaction structure --------------------------------------

/// Pays a friend 10,000 sats and takes 89,000 back as change.
void chapter13Transaction() {
  print('--- Chapter 13 - Transaction structure ---');

  Transaction transaction = unsignedTransaction();
  print('Unsigned Transaction : ${transaction.serialize()}');
  print('Transaction ID : ${transaction.transactionHash}');
}

// --- Chapter 15 — Signature --------------------------------------------------

/// Signs the chapter 13 transaction with ECDSA and checks the result.
void chapter15Signature() {
  print('--- Chapter 15 - Signature ---');

  SingleSignatureVault wallet = myWallet();
  Transaction transaction = unsignedTransaction();
  TransactionOutput utxo = spentUtxo();

  String sigHash = transaction.getSigHash(0, utxo, AddressType.p2wpkh);
  print('SigHash : $sigHash');

  Uint8List signature = wallet.keyStore
      .getChildHdWallet(false)
      .derive(0)
      .signEcdsa(Codec.decodeHex(sigHash));
  Uint8List publicKey = wallet.keyStore.getPublicKeyBytes(0);
  transaction.inputs[0].setSignature(AddressType.p2wpkh,
      [Signature(Codec.encodeHex(signature), Codec.encodeHex(publicKey))]);

  print('Raw Transaction : ${transaction.serialize()}');
  print('Valid Signature? : ${transaction.validateEcdsa(0, utxo)}');
}
