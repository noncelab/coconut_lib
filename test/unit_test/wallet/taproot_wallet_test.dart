@Tags(['unit'])
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../mock_factory.dart';

void main() {
  group('TaprootWallet', () {
    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
    });

    group('fromSeedList', () {
      test('rejects seed-bearing key stores', () {
        expect(
            () => TaprootWallet.fromSeedList(
                [MockFactory.getCommonSeed(passphrase: 'A')], []),
            throwsArgumentError);
      });
    });

    group('fromKeyStoreList', () {
      test('rejects a seed-bearing key store', () {
        final KeyStore keyStore = KeyStore.fromSeed(
            MockFactory.getCommonSeed(passphrase: 'A'), AddressType.p2tr);

        expect(() => TaprootWallet.fromKeyStoreList([keyStore], []),
            throwsArgumentError);
      });

      test('rejects a policy with a seed-bearing beneficiary key store', () {
        final TaprootVault vault = MockFactory.createP2trVaultOnlyKeys();
        final KeyStore beneficiaryKeyStore = KeyStore.fromSeed(
            MockFactory.getCommonSeed(passphrase: 'B'), AddressType.p2tr);
        final InheritancePolicy policy =
            InheritancePolicy(beneficiaryKeyStore, 1000);

        expect(
            () => TaprootWallet.fromKeyStoreList([
                  KeyStore.fromExtendedPublicKey(
                      vault.keyStoreList[0].extendedPublicKey.serialize(),
                      vault.keyStoreList[0].masterFingerprint)
                ], [
                  policy
                ]),
            throwsArgumentError);
      });
    });

    group('fromDescriptor', () {
      test('parses taproot descriptor with miniscripts', () {
        final TaprootVault vault = MockFactory.createP2trVaultWithPolicies();
        expect(vault.descriptor, contains('after('));
        final TaprootWallet wallet =
            TaprootWallet.fromDescriptor(vault.descriptor);
        expect(wallet.keyStoreList.length, vault.keyStoreList.length);
        expect(wallet.policyList.length, greaterThan(0));
      });

      test('rejects descriptor using relative older as inheritance policy', () {
        final TaprootVault vault = MockFactory.createP2trVaultWithPolicies();
        final String canonicalBody = vault.descriptor.split('#').first;
        final String legacyBody = canonicalBody.replaceAll('after(', 'older(');
        final String legacyDescriptor =
            '$legacyBody#${Checksum.getChecksum(legacyBody)}';

        expect(() => TaprootWallet.fromDescriptor(legacyDescriptor),
            throwsException);
      });

      test('throws on non-taproot descriptor', () {
        final p2wpkh = MockFactory.createP2wpkhVault();
        expect(() => TaprootWallet.fromDescriptor(p2wpkh.descriptor),
            throwsException);
      });
    });

    group('fromKeyOriginExpression', () {
      test('creates singlesig wallet', () {
        final wallet = MockFactory.createP2trKeyPathSpendingVault();
        final expr = wallet.getKeyOriginExpression().split(',').first;
        final parsed = TaprootWallet.fromKeyOriginExpression(expr);
        expect(parsed.keyStoreList.length, 1);
        expect(parsed.policyList, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes wallet', () {
        final wallet = TaprootWallet.fromDescriptor(
          MockFactory.createP2trVaultWithPolicies().descriptor,
        );
        expect(wallet.toJson(), isNotEmpty);
      });
    });

    group('TaprootWallet.fromJson', () {
      test('restores policies from serialized wallet', () {
        final TaprootWallet original = TaprootWallet.fromDescriptor(
          MockFactory.createP2trVaultWithPolicies().descriptor,
        );
        final restored = TaprootWallet.fromJson(original.toJson());
        expect(restored.keyStoreList.length, original.keyStoreList.length);
        expect(restored.policyList.length, original.policyList.length);
        expect(restored.derivationPath, original.derivationPath);
      });

      test('throws when json is vault payload', () {
        final vault = MockFactory.createP2trVaultWithPolicies();
        expect(() => TaprootWallet.fromJson(vault.toJson()), throwsException);
      });
    });
  });
}
