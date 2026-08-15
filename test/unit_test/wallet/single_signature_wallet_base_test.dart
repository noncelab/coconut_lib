@Tags(['unit'])
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('SingleSignatureWalletBase', () {
    late SingleSignatureVault vault;
    late SingleSignatureWallet wallet;
    setUp(() {
      vault = WalletFixture.p2wpkhVault();
      wallet = SingleSignatureWallet.fromDescriptor(vault.descriptor);
    });
    group('isVault', () {
      test('Check the object is vault', () {
        expect(wallet.isVault, false);
        expect(vault.isVault, true);
      });
    });
    group('keyStore', () {
      test('Get key store from wallet base', () {
        expect(vault.keyStore.masterFingerprint,
            wallet.keyStore.masterFingerprint);
      });
    });
    group('getAddress', () {
      test('Get address of wallet base', () {
        NetworkType.setNetworkType(NetworkType.testnet);
        expect(
            wallet.getAddress(0), 'tb1qk4z5ysfc2k72pz2ws4dhskxdq772s7uqc35dp9');
        expect(wallet.getAddress(0, isChange: true),
            'tb1qyg29ghzqe5fweer9tyga4dtccxhnx4yqudfygp');
      });
    });
    group('getAddressWithDerivationPath', () {
      test('Get addresss with derivation path', () {
        expect(wallet.getAddressWithDerivationPath("m/84'/1'/0'/0/0"),
            "tb1qk4z5ysfc2k72pz2ws4dhskxdq772s7uqc35dp9");
        expect(wallet.getAddressWithDerivationPath("m/84'/1'/0'/1/0"),
            "tb1qyg29ghzqe5fweer9tyga4dtccxhnx4yqudfygp");
      });

      test('rejects paths outside the wallet account', () {
        expect(() => wallet.getAddressWithDerivationPath("m/84'/1'/1'/0/0"),
            throwsException);
        expect(() => wallet.getAddressWithDerivationPath("m/84'/1'/0x/0/0"),
            throwsException);
      });
    });
    group('getKeyOriginExpression', () {
      test('Get key origin expression', () {
        expect(wallet.getKeyOriginExpression().isNotEmpty, true);
      });
    });
    group('hasPublicKeyInPsbt', () {
      test('Can right vault can sign', () {
        Psbt psbt = PsbtFixture.p2wpkhUnsigned();
        expect(vault.hasPublicKeyInPsbt(psbt.serialize()), true);

        SingleSignatureVault targetVault = SingleSignatureVault.random();
        expect(targetVault.hasPublicKeyInPsbt(psbt.serialize()), false);
      });
    });
    group('addSignatureToPsbt', () {
      test('Sign to psbt', () {
        Psbt psbt = PsbtFixture.p2wpkhUnsigned();
        String signedPsbt = vault.addSignatureToPsbt(psbt.serialize());
        expect(signedPsbt.hashCode, 695547130);
      });

      test('throws when psbt address type mismatches', () {
        Psbt psbt = PsbtFixture.p2wshUnsigned();
        expect(
            () => vault.addSignatureToPsbt(psbt.serialize()), throwsException);
      });

      test('rejects a witness UTXO that does not belong to the vault', () {
        final Psbt psbt = PsbtFixture.p2wpkhUnsigned();
        final SingleSignatureVault foreignVault =
            WalletFixture.p2wpkhVault(passphrase: 'foreign');
        final int amount = psbt.inputs.single.witnessUtxo!.amount;
        final TransactionOutput foreignUtxo =
            TransactionOutput.forPayment(amount, foreignVault.getAddress(0));
        psbt.psbtMap['inputs'][0]['01'] = foreignUtxo.serialize();
        final String forgedPsbt = psbt.serialize();

        expect(Psbt.parse(forgedPsbt).matchesVault(vault), isFalse);
        expect(
            () => vault.addSignatureToPsbt(forgedPsbt),
            throwsA(isA<PsbtException>().having(
                (error) => error.code, 'code', PsbtErrorCode.utxoMismatch)));
      });
    });
  });
}
