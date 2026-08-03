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
      test('creates key stores and valid address', () {
        final wallet = TaprootWallet.fromSeedList(
            [MockFactory.getCommonSeed(passphrase: 'A')], []);
        expect(wallet.keyStoreList.length, 1);
        expect(wallet.getAddress(0).startsWith('bcrt1p'), true);
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

      test('legacy older descriptor preserves addresses and tapleaf hashes',
          () {
        final TaprootVault vault = MockFactory.createP2trVaultWithPolicies();
        final String canonicalBody = vault.descriptor.split('#').first;
        final String legacyBody = canonicalBody.replaceAll('after(', 'older(');
        final String legacyDescriptor =
            '$legacyBody#${Checksum.getChecksum(legacyBody)}';

        final canonical = TaprootWallet.fromDescriptor(vault.descriptor);
        final legacy = TaprootWallet.fromDescriptor(legacyDescriptor);

        expect(legacy.getAddress(0), canonical.getAddress(0));
        expect(legacy.policyList.length, canonical.policyList.length);
        for (int i = 0; i < legacy.policyList.length; i++) {
          expect(legacy.policyList[i].getTapleafHash(0),
              canonical.policyList[i].getTapleafHash(0));
        }
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
