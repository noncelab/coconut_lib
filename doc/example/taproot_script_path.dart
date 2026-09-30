import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';

/// Signs the same Taproot output through its key path and inheritance script.
void main() {
  NetworkType.setNetworkType(NetworkType.regtest);
  const receiveAddress = 'bcrt1qxdyjf6h5d6qxap4n2dap97q4j5ps6ua8jkxz0z';
  const mnemonic =
      'machine crack daughter fish credit glare raven fever tunnel delay fish record';

  KeyStore keyStore(String passphrase) => KeyStore.fromSeed(
      Seed.fromMnemonic(utf8.encode(mnemonic),
          passphrase: utf8.encode(passphrase)),
      AddressType.p2tr);

  // The beneficiary owns the key committed by the inheritance leaf.
  final childVault =
      TaprootVault.fromKeyStoreList([keyStore('beneficiary')], []);
  final policy = InheritancePolicy.fromDescriptorAndLocktime(
      childVault.descriptor, 1767225600);

  // Two parent keys form the MuSig2 internal key; the policy forms a Tapleaf.
  final parentVault = TaprootVault.fromKeyStoreList(
      [keyStore('parent A'), keyStore('parent B')], [policy]);

  // A beneficiary imports the public descriptor and binds only its own seed.
  final beneficiaryVault = TaprootVault.fromDescriptor(parentVault.descriptor);
  beneficiaryVault
      .bindSeedToBeneficiaryKeyStore(childVault.keyStoreList[0].seed);

  final parentWallet = TaprootWallet.fromDescriptor(parentVault.descriptor);
  final beneficiaryWallet =
      TaprootWallet.fromDescriptor(beneficiaryVault.descriptor);

  // Both spends below consume this one output, two ways.
  final utxo = Utxo(
      '67991bbaf00a36e647593072409b2148f6fb622e6b2dff3112b4c1f9db92f756',
      1,
      21000,
      "m/86'/1'/0'/0/0");

  // Key-path spending requires the MuSig2 public-nonce round.
  final keyPathTransaction = Transaction.forSinglePayment(
      [utxo], receiveAddress, "m/86'/1'/0'/1/0", 20000, 1, parentWallet);
  final unsignedKeyPathPsbt =
      Psbt.fromTransaction(keyPathTransaction, parentWallet);
  final noncePsbt = parentVault.addPublicNonce(unsignedKeyPathPsbt.serialize());
  final signedKeyPathPsbt =
      Psbt.parse(parentVault.addSignatureToPsbt(noncePsbt));
  final signedKeyPathTransaction =
      signedKeyPathPsbt.getSignedTransaction(parentWallet.addressType);

  // Script-path spending selects the inheritance policy before PSBT creation:
  // setPolicy also sets the locktime the leaf's CLTV requires.
  final scriptPathTransaction = Transaction.forSinglePayment(
      [utxo], receiveAddress, "m/86'/1'/0'/1/0", 20000, 1, beneficiaryWallet);
  scriptPathTransaction.setPolicy(beneficiaryWallet.policyList.first);
  final unsignedScriptPathPsbt =
      Psbt.fromTransaction(scriptPathTransaction, beneficiaryWallet);
  final signedScriptPathPsbt = Psbt.parse(
      beneficiaryVault.addSignatureToPsbt(unsignedScriptPathPsbt.serialize()));
  final signedScriptPathTransaction =
      signedScriptPathPsbt.getSignedTransaction(beneficiaryWallet.addressType);

  // The prevout both spends consume, rebuilt so the signatures can be checked.
  final spentOutput =
      TransactionOutput.forPayment(utxo.amount, parentWallet.getAddress(0));

  print('Key-path transaction: ${signedKeyPathTransaction.serialize()}');
  print('Valid key-path signature: '
      '${signedKeyPathTransaction.validateSchnorr(0, [spentOutput])}');
  print('Script-path transaction: ${signedScriptPathTransaction.serialize()}');
  print('Valid script-path witness: '
      '${signedScriptPathTransaction.validateSpend([spentOutput])}');
}
