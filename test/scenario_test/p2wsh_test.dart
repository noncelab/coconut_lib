@Tags(['scenario'])
library;

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../fixtures/test_fixtures.dart';

void main() {
  test('Add signature to psbt scenario', () {
    NetworkType.setNetworkType(NetworkType.mainnet);
    SingleSignatureVault vault1 = WalletFixture.p2wpkhVault(passphrase: 'A');
    SingleSignatureVault vault2 = WalletFixture.p2wpkhVault(passphrase: 'B');
    SingleSignatureVault vault3 = WalletFixture.p2wpkhVault(passphrase: 'C');

    KeyStore keyStore1 =
        KeyStore.fromSeed(vault1.keyStore.seed, AddressType.p2wsh);
    KeyStore keyStore2 =
        KeyStore.fromSeed(vault2.keyStore.seed, AddressType.p2wsh);
    KeyStore keyStore3 =
        KeyStore.fromSeed(vault3.keyStore.seed, AddressType.p2wsh);

    MultisignatureVault multiSigVault1 = MultisignatureVault.fromKeyStoreList([
      keyStore1,
      KeyStore.fromSignerBsms(vault2.getSignerBsms(AddressType.p2wsh, "")),
      KeyStore.fromSignerBsms(vault3.getSignerBsms(AddressType.p2wsh, ""))
    ], 2, addressType: AddressType.p2wsh);

    MultisignatureVault multiSigVault2 =
        MultisignatureVault.fromCoordinatorBsms(
            multiSigVault1.getCoordinatorBsms());
    multiSigVault2.bindSeedToKeyStore(keyStore2.seed);

    // ignore: unused_local_variable
    MultisignatureVault multiSigVault3 =
        MultisignatureVault.fromCoordinatorBsms(
            multiSigVault1.getCoordinatorBsms());
    multiSigVault2.bindSeedToKeyStore(keyStore3.seed);

    MultisignatureWallet wallet =
        MultisignatureWallet.fromDescriptor(multiSigVault1.descriptor);

    Transaction tx = Transaction.forSinglePayment(
        UtxoFixture.list(
            count: 2, derivationPath: '${multiSigVault1.derivationPath}/0/0'),
        multiSigVault1.getAddress(1),
        '${multiSigVault1.derivationPath}/1/1',
        15000,
        3,
        multiSigVault1);
    Psbt unsignedTx = Psbt.fromTransaction(tx, multiSigVault1);

    expect(unsignedTx.matchesVault(multiSigVault1), true);
    expect(unsignedTx.matchesVault(multiSigVault2), true);

    expect(unsignedTx.addressType, AddressType.p2wsh);

    String signed1PsbtText =
        multiSigVault1.addSignatureToPsbt(unsignedTx.serialize());
    // print(signed1PsbtText);
    String signed2PsbtText = multiSigVault2.addSignatureToPsbt(signed1PsbtText);
    // String signed3PsbtText = multiSigVault3.addSignatureToPsbt(signed2PsbtText);

    // print(Psbt.parse(signed3PsbtText).inputs[0].partialSig!.length);

    final Psbt signedPsbt = Psbt.parse(signed2PsbtText);
    final Transaction signedTransaction =
        signedPsbt.getSignedTransaction(wallet.addressType);

    expect(signedPsbt.inputs.every((input) => input.signedCount == 2), isTrue);
    expect(signedTransaction.serialize(), isNotEmpty);
  });
}
