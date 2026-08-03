@Tags(['unit'])
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../mock_factory.dart';

void main() {
  group('InheritancePolicy', () {
    late TaprootVault beneficiaryVault;

    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
      beneficiaryVault = MockFactory.createBeneficiaryVault(passphrase: 'B');
    });

    group('fromDescriptorAndLocktime', () {
      test('creates policy for taproot-only beneficiary descriptor', () {
        final InheritancePolicy p = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 1234567890);
        expect(p.locktime, 1234567890);
        expect(p.beneficiaryKeyStore.masterFingerprint,
            beneficiaryVault.keyStoreList[0].masterFingerprint);
      });

      test('throws when descriptor is not taproot', () {
        final SingleSignatureVault p2wpkh = MockFactory.createP2wpkhVault();
        expect(
            () => InheritancePolicy.fromDescriptorAndLocktime(
                p2wpkh.descriptor, 1),
            throwsException);
      });

      test('throws when descriptor embeds tap scripts', () {
        final TaprootVault vaultWithScripts =
            MockFactory.createP2trVaultWithPolicies();
        expect(
            () => InheritancePolicy.fromDescriptorAndLocktime(
                vaultWithScripts.descriptor, 1),
            throwsException);
      });
    });

    group('fromMiniscript', () {
      test('roundtrips key origin expression', () {
        final InheritancePolicy original =
            InheritancePolicy.fromDescriptorAndLocktime(
                beneficiaryVault.descriptor, 987654321);
        final Policy parsed =
            InheritancePolicy.fromMiniscript(original.toMiniscript());
        expect(parsed, isA<InheritancePolicy>());
        expect((parsed as InheritancePolicy).locktime, original.locktime);
      });
    });

    group('toScript', () {
      test('encodes CLTV + DROP + x-only pubkey + CHECKSIG', () {
        final InheritancePolicy p = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 1000);
        final Script s = p.toScript(0);
        expect(s.commands.length, 5);
        expect(s.commands[1],
            ScriptOperationCode.getHex('OP_CHECKLOCKTIMEVERIFY'));
        expect(s.commands[2], ScriptOperationCode.getHex('OP_DROP'));
        expect(s.commands[3], isA<Uint8List>());
        expect((s.commands[3] as Uint8List).length, 32);
        expect(s.commands[4], ScriptOperationCode.getHex('OP_CHECKSIG'));
      });
    });

    group('toJson', () {
      test('serializes policy', () {
        final policy = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 555666777);
        expect(policy.toJson(), isNotEmpty);
      });
    });

    group('InheritancePolicy.fromJson', () {
      test('restores beneficiary key store and locktime', () {
        final InheritancePolicy original =
            InheritancePolicy.fromDescriptorAndLocktime(
                beneficiaryVault.descriptor, 555666777);
        final InheritancePolicy restored =
            InheritancePolicy.fromJson(original.toJson());
        expect(restored.locktime, original.locktime);
        expect(restored.beneficiaryKeyStore.masterFingerprint,
            original.beneficiaryKeyStore.masterFingerprint);
      });
    });
  });
}
