import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';

const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

SingleSignatureVault _signer(String passphrase) {
  return SingleSignatureVault.fromMnemonic(utf8.encode(_mnemonic),
      passphrase: utf8.encode(passphrase));
}

/// Coordinates two signers for a 2-of-3 native SegWit transaction.
void main() {
  NetworkType.setNetworkType(NetworkType.regtest);

  final signerA = _signer('A');
  final signerB = _signer('B');
  final signerC = _signer('C');

  // The coordinator initially owns signer A's seed and imports public BSMS
  // records for the other participants.
  final coordinatorVault = MultisignatureVault.fromKeyStoreList([
    KeyStore.fromSeed(signerA.keyStore.seed, AddressType.p2wsh),
    KeyStore.fromSignerBsms(
        signerB.getSignerBsms(AddressType.p2wsh, 'Signer B')),
    KeyStore.fromSignerBsms(
        signerC.getSignerBsms(AddressType.p2wsh, 'Signer C')),
  ], 2);

  // Signer B imports the coordinator record and binds only its own seed.
  final signerBVault = MultisignatureVault.fromCoordinatorBsms(
      coordinatorVault.getCoordinatorBsms());
  signerBVault.bindSeedToKeyStore(signerB.keyStore.seed);

  final wallet =
      MultisignatureWallet.fromDescriptor(coordinatorVault.descriptor);
  final utxo = Utxo(
      '0b5b43a8a09f1021bac4f4357c2808043b409231b42fc0143050ac37668a984b',
      0,
      21000,
      "${wallet.derivationPath}/0/0");
  final transaction = Transaction.forSinglePayment([utxo], wallet.getAddress(1),
      "${wallet.derivationPath}/1/0", 2000, 2, wallet);

  final unsignedPsbt = Psbt.fromTransaction(transaction, wallet).serialize();
  final onceSignedPsbt = coordinatorVault.addSignatureToPsbt(unsignedPsbt);
  final fullySignedPsbt = signerBVault.addSignatureToPsbt(onceSignedPsbt);
  final signedTransaction =
      Psbt.parse(fullySignedPsbt).getSignedTransaction(wallet.addressType);

  print('2-of-3 address: ${wallet.getAddress(0)}');
  print('Signed transaction: ${signedTransaction.serialize()}');
}
