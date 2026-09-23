// ignore_for_file: file_names
// ---------------------------------------------------------------------------
// Journey of 100k Sats
//
// Worked examples from the book 『비트코인 프로토콜 — 10만 사토시의 여정』.
// Every chapter of the book has a matching function below, and the numbers
// printed here are the exact numbers printed in the book. Run the file and it
// walks the whole journey, from a coin flip to a spendable address.
//
//   dart run src/journey-of-100k-sats.dart        run every chapter
//   dart run src/journey-of-100k-sats.dart 1      run chapter 1 only
//
// WARNING
// Every secret in this file is published in a book. Anyone holding a copy can
// derive the private keys. Never send real bitcoin to an address derived from
// these values.
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';

void main() {
  NetworkType.setNetworkType(NetworkType.mainnet);
  // Chapter 1 - Entropy and the mnemonic
  print("--- Chapter 1 - Entropy and the mnemonic ---");
  String entropyBits =
      "10011110100010000101110110010101001010101101001101100010110010101110101101001110111111100011010010101000111010010001101111010010";
  Uint8List hexEntropy = Converter.binToBytes(entropyBits);
  Uint8List mnemonic = Seed.fromEntropy(hexEntropy).mnemonic;

  print("Entropy Bits : $entropyBits");
  print("Hex Entropy : ${Codec.encodeHex(hexEntropy)}");
  print('Mnemonic : ${utf8.decode(mnemonic)}');

  // Chapter 2 - Seed
  print("--- Chapter 2 - Seed ---");
  Seed seed = Seed.fromMnemonic(mnemonic,
      passphrase: utf8.encode('coffee with alex at seven'));
  print("Seed : ${Codec.encodeHex(seed.rootSeed)}");

  // Chapter 3 - HD Wallet
  print("--- Chapter 3 - HD Wallet ---");
  KeyStore keyStore = KeyStore.fromSeed(seed, AddressType.p2wpkh);
  print("Receive Private Key 0 : ${keyStore.getPrivateKey(0)}");
  print("Receive Private Key 1 : ${keyStore.getPrivateKey(1)}");

  // Chapter 9 - Extende Public Key
  print("--- Chapter 9 - Extende Public Key ---");
  print("xPub : ${keyStore.extendedPublicKey.serialize()}");
  SingleSignatureVault wallet = SingleSignatureVault.fromKeyStore(keyStore);
  print("Descriptor : ${wallet.descriptor}");

  // Chapter 10 - Address
  print("--- Chapter 10 - Address ---");
  print("Receive Address 0 : ${wallet.getAddress(0)}");

  // Chapter 13 - Transaction Structure
  print("--- Chapter 13 - Transaction Structure ---");
  const String friendAddress = 'bc1qng0nk3xgye50vkjsc448cuu335s7xa4lnnx0sy';
  String changeAddress = wallet.getAddress(0, isChange: true);
  const String previousTxId =
      '13b394e8f3f13757392c827aac46802bc4a17be3285a8035bc5d91758fbfe1c6';
  const int previousOutputIndex = 0;
  const int sequence = 0xfffffffd;
  TransactionInput input = TransactionInput(
      Uint8List.fromList(Codec.decodeHex(previousTxId).reversed.toList()),
      Converter.intToLittleEndianBytes(previousOutputIndex, 4),
      ScriptSignature.empty(),
      Converter.intToLittleEndianBytes(sequence, 4));
  TransactionOutput sendingOutput =
      TransactionOutput.forPayment(10000, friendAddress);
  TransactionOutput changeOutput =
      TransactionOutput.forPayment(89000, changeAddress);
  Transaction transaction = Transaction.withInputsAndOutputs(
      [input], [sendingOutput, changeOutput], AddressType.p2wpkh);
  print("Unsigned Tranaction : ${transaction.serialize()}");
  print("Transaction ID : ${transaction.transactionHash}");

  // Chapter 11 - ECDSA
  print("--- Chapter 11 - ECDSA ---");
  TransactionOutput outputUtxo =
      TransactionOutput.forPayment(100000, wallet.getAddress(0));
  Uint8List publicKey = wallet.keyStore.getPublicKeyBytes(0);
  String sigHash = transaction.getSigHash(0, outputUtxo, AddressType.p2wpkh);
  print("SigHash : $sigHash");
  Uint8List signature = wallet.keyStore
      .getChildHdWallet(false)
      .derive(0)
      .signEcdsa(Codec.decodeHex(sigHash));

  transaction.inputs[0].setSignature(AddressType.p2wpkh,
      [Signature(Codec.encodeHex(signature), Codec.encodeHex(publicKey))]);
  print("Raw Transaction : ${transaction.serialize()}");
  print("Valid Signature? : ${transaction.validateEcdsa(0, outputUtxo)}");
}
