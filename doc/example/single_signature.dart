import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';

/// Builds, signs, and finalizes a native SegWit single-signature transaction.
void main() {
  NetworkType.setNetworkType(NetworkType.regtest);

  // Vaults retain private material and perform signing.
  final seed = Seed.fromMnemonic(utf8.encode(
      'thank split shrimp error own spirit slow glow act evidence globe slight'));
  final vault = SingleSignatureVault.fromSeed(seed);

  // Wallets are watch-only and can be shared with an online application.
  final wallet = SingleSignatureWallet.fromDescriptor(vault.descriptor);

  final utxo = Utxo(
      '393a2d56f910019a6df975672989a449648f355b1fb7889fb831f0402c5550f3',
      0,
      21000,
      "${wallet.derivationPath}/0/0");
  final transaction = Transaction.forSinglePayment([utxo], wallet.getAddress(1),
      "${wallet.derivationPath}/1/0", 2000, 2, wallet);

  final unsignedPsbt = Psbt.fromTransaction(transaction, wallet);
  final signedPsbt = vault.addSignatureToPsbt(unsignedPsbt.serialize());
  final signedTransaction =
      Psbt.parse(signedPsbt).getSignedTransaction(wallet.addressType);

  print('Wallet address: ${wallet.getAddress(0)}');
  print('Signed transaction: ${signedTransaction.serialize()}');
}
