@Tags(['scenario'])
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../mock_factory.dart';

void main() {
  test('Add signature to psbt scenario', () {
    SingleSignatureVault vault = MockFactory.createP2wpkhVault();

    expect(vault.descriptor.hashCode, 186870090);

    SingleSignatureWallet wallet =
        SingleSignatureWallet.fromDescriptor(vault.descriptor);

    Psbt unsignedTx = MockFactory.createP2wpkhUnsignedPsbt();

    expect(unsignedTx.matchesVault(vault), true);
    expect(
        unsignedTx.matchesVault(MockFactory.createP2wpkhVault(passphrase: 'Z')),
        false);

    expect(unsignedTx.addressType, AddressType.p2wpkh);

    String signedPsbtText = vault.addSignatureToPsbt(unsignedTx.serialize());

    Transaction signedTransaction =
        Psbt.parse(signedPsbtText).getSignedTransaction(wallet.addressType);

    expect(
        signedTransaction.serialize(),
        MockFactory.createP2wpkhSignedPsbt()
            .getSignedTransaction(wallet.addressType)
            .serialize());
  });

  test('Batch transaction scenario', () {
    NetworkType.setNetworkType(NetworkType.regtest);

    SingleSignatureVault vault = MockFactory.createP2wpkhVault();

    String receiver1 =
        vault.getAddress(11); //bcrt1q7af8g5eruxaaqrnyfc3cvx65rmv62mcdhvu6av
    String receiver2 =
        vault.getAddress(12); //bcrt1qc2cymquyddm5spjjtsuhvjk4e2n03wcznk346k

    Utxo utxo = Utxo(
        '81929c81f71c5168c63b3a76a13a56589397650568e3f31238bf37678249f7fb',
        0,
        21000,
        "${vault.derivationPath}/0/10");

    Map<String, int> receiveMap = {receiver1: 5000, receiver2: 5000};

    String changeAddressDerivationPath = "m/84'/1'/0'/1/10";

    Transaction unsignedTx = Transaction.forBatchPayment(
        [utxo], receiveMap, changeAddressDerivationPath, 3, vault);

    unsignedTx.setOutputDerivationPath(
        "bcrt1q7af8g5eruxaaqrnyfc3cvx65rmv62mcdhvu6av", "m/84'/1'/0'/0/11");
    unsignedTx.setOutputDerivationPath(
        "bcrt1qc2cymquyddm5spjjtsuhvjk4e2n03wcznk346k", "m/84'/1'/0'/0/12");

    Psbt signedPsbt = Psbt.parse(vault.addSignatureToPsbt(
        Psbt.fromTransaction(unsignedTx, vault).serialize()));

    // print(signedPsbt.serialize());

    expect(
        signedPsbt.getSignedTransaction(vault.addressType).serialize().hashCode,
        923661255);
  });
}
