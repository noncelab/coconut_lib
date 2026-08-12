import 'package:coconut_lib/coconut_lib.dart';

void main() async {
  NetworkType.setNetworkType(NetworkType.regtest);
  const receiveAddress = 'bcrt1qxdyjf6h5d6qxap4n2dap97q4j5ps6ua8jkxz0z';

  // Child vault 는 싱글시그 p2tr만 지원합니다.
  TaprootVault childVault =
      TaprootVault.fromKeyStoreList([KeyStore.random(AddressType.p2tr)], []);
  // 정책을 만듭니다. 상속자의 descriptor와 unix time을 입력합니다.
  Policy policy = InheritancePolicy.fromDescriptorAndLocktime(
      childVault.descriptor, 1767225600);
  // parent vault를 만듭니다. TaprootVault.fromKeyStoreList([여러개의 KeyStore를 넣으면 멀티시그가 지원됩니다.],[정책을 여러개 넣으면 다양한 정책이 지원됩니다.])
  TaprootVault parentVault = TaprootVault.fromKeyStoreList(
      [KeyStore.random(AddressType.p2tr), KeyStore.random(AddressType.p2tr)],
      [policy]);

  // 상속자를 위한 vault를 받아옵니다. 새로운 vault 가 생성됩니다. 하지만 상속자의 seed는 연결되지 않습니다.
  TaprootVault beneficiaryVault =
      TaprootVault.fromDescriptor(parentVault.descriptor);
  // 만든 상속 지갑에 상속자의 seed를 연결합니다.
  beneficiaryVault
      .bindSeedToBeneficiaryKeyStore(childVault.keyStoreList[0].seed);

  // 와치온리를 만듭니다.
  TaprootWallet parentWallet =
      TaprootWallet.fromDescriptor(parentVault.descriptor);
  TaprootWallet beneficiaryWallet =
      TaprootWallet.fromDescriptor(beneficiaryVault.descriptor);

  // 부모가 spending 하는 경우 (중간에 nonce 필요함 주의)
  Utxo utxo = Utxo(
      '67991bbaf00a36e647593072409b2148f6fb622e6b2dff3112b4c1f9db92f756',
      1,
      21000,
      "m/86'/1'/0'/0/0");
  Transaction tx1 = Transaction.forSinglePayment(
      [utxo], receiveAddress, "m/86'/1'/0'/1/0", 20000, 1, parentWallet);
  Psbt unsignedPsbt1 = Psbt.fromTransaction(tx1, parentVault);
  String noncePsbt1 = parentVault.addPublicNonce(unsignedPsbt1.serialize());
  Psbt signedPsbt1 = Psbt.parse(parentVault.addSignatureToPsbt(noncePsbt1));
  Transaction signedTx1 =
      signedPsbt1.getSignedTransaction(parentWallet.addressType);
  print(signedTx1.serialize());

  // 상속자가 spending 하는 경우
  Transaction tx2 = Transaction.forSinglePayment(
      [utxo], receiveAddress, "m/86'/1'/0'/1/0", 20000, 1, beneficiaryWallet);
  Psbt unsignedPsbt2 = Psbt.fromTransaction(tx2, beneficiaryVault);
  Psbt signedPsbt2 = Psbt.parse(
      beneficiaryVault.addSignatureToPsbt(unsignedPsbt2.serialize()));
  Transaction signedTx =
      signedPsbt2.getSignedTransaction(beneficiaryWallet.addressType);
  print(signedTx.serialize());
}
