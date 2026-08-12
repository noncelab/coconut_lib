@Tags(['unit'])
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('TaprootWallet', () {
    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
    });

    group('fromSeedList', () {
      test('rejects seed-bearing key stores', () {
        expect(
            () => TaprootWallet.fromSeedList(
                [SeedFixture.common(passphrase: 'A')], []),
            throwsArgumentError);
      });
    });

    group('fromKeyStoreList', () {
      test('copies key stores and policies and exposes immutable lists', () {
        final TaprootVault vault = WalletFixture.p2trPolicyVault();
        final KeyStore parent = KeyStore.fromExtendedPublicKey(
            vault.keyStoreList.first.extendedPublicKey.serialize(),
            vault.keyStoreList.first.masterFingerprint);
        final InheritancePolicy originalPolicy =
            vault.policyList.whereType<InheritancePolicy>().first;
        final KeyStore beneficiary = KeyStore.fromExtendedPublicKey(
            originalPolicy.beneficiaryKeyStore.extendedPublicKey.serialize(),
            originalPolicy.beneficiaryKeyStore.masterFingerprint);
        final policy = InheritancePolicy(beneficiary, originalPolicy.locktime);
        final wallet = TaprootWallet.fromKeyStoreList([parent], [policy]);

        expect(wallet.keyStoreList.first, isNot(same(parent)));
        expect(wallet.keyStoreList.first.hdWallet.isNeutered(), isTrue);
        final copiedPolicy = wallet.policyList.single as InheritancePolicy;
        expect(copiedPolicy, isNot(same(policy)));
        expect(copiedPolicy.beneficiaryKeyStore, isNot(same(beneficiary)));
        expect(copiedPolicy.beneficiaryKeyStore.hdWallet.isNeutered(), isTrue);
        expect(() => wallet.keyStoreList.clear(), throwsUnsupportedError);
        expect(() => wallet.policyList.clear(), throwsUnsupportedError);
      });

      test('rejects a seed-bearing key store', () {
        final KeyStore keyStore = KeyStore.fromSeed(
            SeedFixture.common(passphrase: 'A'), AddressType.p2tr);

        expect(() => TaprootWallet.fromKeyStoreList([keyStore], []),
            throwsArgumentError);
      });

      test('rejects a policy with a seed-bearing beneficiary key store', () {
        final TaprootVault vault = WalletFixture.p2trMultikeyVault();
        final KeyStore beneficiaryKeyStore = KeyStore.fromSeed(
            SeedFixture.common(passphrase: 'B'), AddressType.p2tr);
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
        final TaprootVault vault = WalletFixture.p2trPolicyVault();
        expect(vault.descriptor, contains('after('));
        final TaprootWallet wallet =
            TaprootWallet.fromDescriptor(vault.descriptor);
        expect(wallet.keyStoreList.length, vault.keyStoreList.length);
        expect(wallet.policyList.length, greaterThan(0));
      });

      test('rejects descriptor using relative older as inheritance policy', () {
        final TaprootVault vault = WalletFixture.p2trPolicyVault();
        final String canonicalBody = vault.descriptor.split('#').first;
        final String legacyBody = canonicalBody.replaceAll('after(', 'older(');
        final String legacyDescriptor =
            '$legacyBody#${Checksum.getChecksum(legacyBody)}';

        expect(() => TaprootWallet.fromDescriptor(legacyDescriptor),
            throwsException);
      });

      test('throws on non-taproot descriptor', () {
        final p2wpkh = WalletFixture.p2wpkhVault();
        expect(() => TaprootWallet.fromDescriptor(p2wpkh.descriptor),
            throwsException);
      });
    });

    group('fromKeyOriginExpression', () {
      test('creates singlesig wallet', () {
        final wallet = WalletFixture.p2trKeyPathVault();
        final expr = wallet.getKeyOriginExpression().split(',').first;
        final parsed = TaprootWallet.fromKeyOriginExpression(expr);
        expect(parsed.keyStoreList.length, 1);
        expect(parsed.policyList, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes wallet', () {
        final wallet = TaprootWallet.fromDescriptor(
          WalletFixture.p2trPolicyVault().descriptor,
        );
        expect(wallet.toJson(), isNotEmpty);
      });
    });

    group('TaprootWallet.fromJson', () {
      test('restores policies from serialized wallet', () {
        final TaprootWallet original = TaprootWallet.fromDescriptor(
          WalletFixture.p2trPolicyVault().descriptor,
        );
        final restored = TaprootWallet.fromJson(original.toJson());
        expect(restored.keyStoreList.length, original.keyStoreList.length);
        expect(restored.policyList.length, original.policyList.length);
        expect(restored.derivationPath, original.derivationPath);
      });

      test('throws when json is vault payload', () {
        final vault = WalletFixture.p2trPolicyVault();
        expect(() => TaprootWallet.fromJson(vault.toJson()), throwsException);
      });
    });
  });
}
