@Tags(['unit'])
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../mock_factory.dart';

void main() {
  group('TaprootVault', () {
    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
    });

    group('fromKeyStoreList', () {
      test('creates vault', () {
        final vault = TaprootVault.fromKeyStoreList(
            [MockFactory.getCommonKeyStore(AddressType.p2tr)], []);
        expect(vault.keyStoreList.length, 1);
        expect(vault.getAddress(0).startsWith('bcrt1p'), true);
      });

      test('creates vault with policies', () {
        InheritancePolicy policy1 = InheritancePolicy.fromDescriptorAndLocktime(
            MockFactory.createBeneficiaryVault(passphrase: 'A').descriptor,
            1767225600);
        InheritancePolicy policy2 = InheritancePolicy.fromDescriptorAndLocktime(
            MockFactory.createBeneficiaryVault(passphrase: 'B').descriptor,
            1767225600);
        final vault = TaprootVault.fromKeyStoreList(
            [MockFactory.getCommonKeyStore(AddressType.p2tr)],
            [policy1, policy2]);
        expect(vault.keyStoreList.length, 1);
        expect(vault.getAddress(0).startsWith('bcrt1p'), true);
      });
      test('check policy order', () {
        InheritancePolicy policy1 = InheritancePolicy.fromDescriptorAndLocktime(
            MockFactory.createBeneficiaryVault(passphrase: 'A').descriptor,
            1767225600);
        InheritancePolicy policy2 = InheritancePolicy.fromDescriptorAndLocktime(
            MockFactory.createBeneficiaryVault(passphrase: 'B').descriptor,
            1767225600);
        final vault1 = TaprootVault.fromKeyStoreList(
            [MockFactory.getCommonKeyStore(AddressType.p2tr)],
            [policy1, policy2]);
        final vault2 = TaprootVault.fromKeyStoreList(
            [MockFactory.getCommonKeyStore(AddressType.p2tr)],
            [policy2, policy1]);
        expect(vault1.getAddress(0), vault2.getAddress(0));
      });
    });

    group('fromSeedList', () {
      test('creates vault', () {
        final vault = TaprootVault.fromSeedList(
            [MockFactory.getCommonSeed(passphrase: 'A')], []);
        expect(vault.keyStoreList.length, 1);
        expect(vault.getAddress(0).startsWith('bcrt1p'), true);
      });
    });

    group('fromCoordinatorBsms', () {
      test('builds key stores from coordinator payload', () {
        final multisig = MockFactory.createP2wshVault();
        final coordinator = multisig.getCoordinatorBsms();
        final vault = TaprootVault.fromCoordinatorBsms(coordinator);
        expect(vault.keyStoreList.length, multisig.keyStoreList.length);
        expect(vault.policyList, isEmpty);
      });
    });

    group('addPublicNonce', () {
      test('returns same psbt for single-key vault', () {
        final vault = MockFactory.createP2trKeyPathSpendingVault();
        final psbt =
            MockFactory.createP2trKeyPathSpendingUnsignedPsbt().serialize();
        expect(vault.addPublicNonce(psbt), psbt);
      });

      test('throws when no keyStore can sign', () {
        final vault = MockFactory.createP2trKeyPathSpendingVault();
        final psbt = MockFactory.createP2wpkhUnsignedPsbt().serialize();
        expect(() => vault.addPublicNonce(psbt), throwsException);
      });
    });

    group('toJson', () {
      test('serializes vault', () {
        final vault = TaprootVault.fromDescriptor(
            MockFactory.createP2trVaultWithPolicies().descriptor);
        expect(vault.toJson(), isNotEmpty);
      });
    });

    group('TaprootVault.fromJson', () {
      test('restores policies from serialized vault', () {
        final original = TaprootVault.fromDescriptor(
            MockFactory.createP2trVaultWithPolicies().descriptor);
        final restored = TaprootVault.fromJson(original.toJson());
        expect(restored.keyStoreList.length, original.keyStoreList.length);
        expect(restored.policyList.length, original.policyList.length);
        expect(restored.derivationPath, original.derivationPath);
      });

      test('throws when wallet payload is passed', () {
        final wallet = TaprootWallet.fromDescriptor(
            MockFactory.createP2trVaultWithPolicies().descriptor);
        expect(() => TaprootVault.fromJson(wallet.toJson()), throwsException);
      });
    });

    group('fromDescriptor', () {
      test('throws on non-taproot descriptor', () {
        final p2wpkh = MockFactory.createP2wpkhVault();
        expect(() => TaprootVault.fromDescriptor(p2wpkh.descriptor),
            throwsException);
      });
    });

    group('bindSeedToBeneficiaryKeyStore', () {
      test('throws when no beneficiary account key matches', () {
        final vault = MockFactory.createP2trVaultWithPolicies();
        final otherSeed = MockFactory.getCommonSeed(passphrase: 'not-matching');
        expect(() => vault.bindSeedToBeneficiaryKeyStore(otherSeed),
            throwsStateError);
      });
    });

    group('bindSeedToKeyStore', () {
      test('throws when no account key matches', () {
        final source = MockFactory.createP2trKeyPathSpendingVault();
        final watchOnly = TaprootVault.fromDescriptor(source.descriptor);
        final otherSeed = MockFactory.getCommonSeed(passphrase: 'not-matching');

        expect(() => watchOnly.bindSeedToKeyStore(otherSeed), throwsStateError);
      });
    });

    group('getSpendablePolicy', () {
      test('throws when no beneficiary seed exists', () {
        final vault = MockFactory.createP2trVaultWithPolicies();
        expect(() => vault.getSpendablePolicy(), throwsException);
      });
    });
  });
}
