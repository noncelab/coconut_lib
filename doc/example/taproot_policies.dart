import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';

/// Builds a Taproot wallet whose script tree has a shape chosen by hand, then
/// spends through its 2-of-2 leaf.
void main() {
  NetworkType.setNetworkType(NetworkType.regtest);
  const receiveAddress = 'bcrt1qxdyjf6h5d6qxap4n2dap97q4j5ps6ua8jkxz0z';
  const mnemonic =
      'machine crack daughter fish credit glare raven fever tunnel delay fish record';

  KeyStore keyStore(String passphrase) => KeyStore.fromSeed(
      Seed.fromMnemonic(utf8.encode(mnemonic),
          passphrase: utf8.encode(passphrase)),
      AddressType.p2tr);

  final owner = keyStore('owner');
  final spouse = keyStore('spouse');
  final child = keyStore('child');
  final backup = keyStore('backup');

  // Three ways to spend besides the owner's key path.
  final recovery = SingleSignaturePolicy(backup);
  final family = MultisignaturePolicy([child, spouse], 2);
  final inheritance = InheritancePolicy(child, 1767225600);

  // The grouping is part of the commitment: {{recovery,family},inheritance}
  // would be a different merkle root, and so a different address.
  final tapTree = TapBranch(
    TapLeaf(recovery),
    TapBranch(TapLeaf(family), TapLeaf(inheritance)),
  );
  final vault = TaprootVault.fromTapTree([owner], tapTree);
  final wallet = TaprootWallet.fromDescriptor(vault.descriptor);

  // Each level down adds a sibling to the control block: 32 witness bytes.
  print('Address: ${wallet.getAddress(0)}');
  print('Tree: ${wallet.tapTree!.toTreeExpression()}');
  for (int i = 0; i < wallet.policyList.length; i++) {
    print('Leaf $i: ${wallet.policyList[i].runtimeType}, '
        'depth ${wallet.getMerklePathLength(i, 0)}, '
        'needs ${wallet.policyList[i].requiredSignature} signature(s)');
  }

  // Spend through the family leaf.
  final utxo = Utxo(
      '67991bbaf00a36e647593072409b2148f6fb622e6b2dff3112b4c1f9db92f756',
      1,
      21000,
      "m/86'/1'/0'/0/0");
  final transaction = Transaction.forSinglePayment(
      [utxo], receiveAddress, "m/86'/1'/0'/1/0", 20000, 1, wallet);
  transaction.setPolicy(wallet.policyList[1]);

  // Each cosigner imports the public descriptor and binds only its own seed,
  // so neither ever holds the other's key.
  String psbt = Psbt.fromTransaction(transaction, wallet).serialize();
  for (final KeyStore cosigner in [child, spouse]) {
    final cosignerVault = TaprootVault.fromDescriptor(vault.descriptor);
    cosignerVault.bindSeedToBeneficiaryKeyStore(cosigner.seed);
    psbt = cosignerVault.addSignatureToPsbt(psbt);
  }

  final signedTransaction =
      Psbt.parse(psbt).getSignedTransaction(wallet.addressType);

  // The prevout the UTXO paid to, rebuilt so the witness can be checked.
  final spentOutput =
      TransactionOutput.forPayment(utxo.amount, wallet.getAddress(0));

  print('Signed transaction: ${signedTransaction.serialize()}');
  print('Witness items: ${signedTransaction.inputs[0].witnessList.length}');
  print('Valid witness: ${signedTransaction.validateSpend([spentOutput])}');
}
