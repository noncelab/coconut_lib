@Tags(['unit'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('LegacyInheritancePolicy', () {
    late TaprootVault beneficiaryVault;
    late LegacyInheritancePolicy policy;

    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
      beneficiaryVault = WalletFixture.beneficiaryVault(passphrase: 'B');
      policy = LegacyInheritancePolicy.fromDescriptorAndLocktime(
          beneficiaryVault.descriptor, 1767225600);
    });

    test('is an InheritancePolicy', () {
      expect(policy, isA<InheritancePolicy>());
      expect(policy.locktime, 1767225600);
    });

    group('toScript', () {
      test('emits <N> CLTV DROP <K> CHECKSIG as raw bytes', () {
        final Uint8List pubkey = beneficiaryVault.keyStoreList[0]
            .getPublicKeyBytes(0, isXOnly: true);
        final List<int> expected = [
          4, ...Converter.intToLittleEndianBytes(1767225600, 4), // <N>
          0xb1, // OP_CHECKLOCKTIMEVERIFY
          0x75, // OP_DROP
          32, ...pubkey, // <K>
          0xac, // OP_CHECKSIG
        ];

        expect(policy.toScript(0).rawSerialize(),
            Codec.encodeHex(Uint8List.fromList(expected)));
      });

      test('follows address index and change branch', () {
        for (final bool isChange in [false, true]) {
          for (final int index in [0, 1, 7]) {
            final Uint8List pubkey = beneficiaryVault.keyStoreList[0]
                .getPublicKeyBytes(index, isChange: isChange, isXOnly: true);
            final List<int> script = Codec.decodeHex(
                policy.toScript(index, isChange: isChange).rawSerialize());
            expect(script.sublist(8, 8 + 32), pubkey);
            expect(script[6], 0x75);
          }
        }
      });

      test('differs from InheritancePolicy only in the cleanup opcode', () {
        final InheritancePolicy standard = InheritancePolicy(
            beneficiaryVault.keyStoreList[0], policy.locktime);
        final List<int> a =
            Codec.decodeHex(standard.toScript(0).rawSerialize());
        final List<int> b = Codec.decodeHex(policy.toScript(0).rawSerialize());

        expect(b.length, a.length);
        expect([
          for (int i = 0; i < a.length; i++)
            if (a[i] != b[i]) i
        ], [
          6
        ]);
        expect(a[6], 0x69);
        expect(b[6], 0x75);
      });

      test('commits to a different tapleaf hash than InheritancePolicy', () {
        final InheritancePolicy standard = InheritancePolicy(
            beneficiaryVault.keyStoreList[0], policy.locktime);

        expect(policy.getTapleafHash(0), isNot(standard.getTapleafHash(0)));
      });
    });

    group('toMiniscript / fromMiniscript', () {
      test('spells the leaf with after_drop', () {
        expect(policy.toMiniscript(),
            startsWith('and_v(after_drop(1767225600),pk('));
        expect(policy.toMiniscript(), isNot(contains('v:after')));
      });

      test('round-trips through Policy.fromMiniscript', () {
        final Policy restored = Policy.fromMiniscript(policy.toMiniscript());

        expect(restored, isA<LegacyInheritancePolicy>());
        expect((restored as LegacyInheritancePolicy).locktime, policy.locktime);
        expect(restored.toScript(0).rawSerialize(),
            policy.toScript(0).rawSerialize());
      });

      test('standard spelling still restores InheritancePolicy', () {
        final InheritancePolicy standard = InheritancePolicy(
            beneficiaryVault.keyStoreList[0], policy.locktime);
        final Policy restored = Policy.fromMiniscript(standard.toMiniscript());

        expect(restored, isA<InheritancePolicy>());
        expect(restored, isNot(isA<LegacyInheritancePolicy>()));
      });

      test('both spellings differ so miniscript equality tells them apart', () {
        final InheritancePolicy standard = InheritancePolicy(
            beneficiaryVault.keyStoreList[0], policy.locktime);

        expect(policy.toMiniscript(), isNot(standard.toMiniscript()));
      });

      test('rejects a malformed after_drop leaf', () {
        expect(
            () => LegacyInheritancePolicy.fromMiniscript(
                'and_v(after_drop(x),pk(abc))'),
            throwsFormatException);
      });
    });

    group('toJson / fromJson', () {
      test('stores the legacy type', () {
        final Map<String, dynamic> json = jsonDecode(policy.toJson());

        expect(json['type'], 'legacyInheritance');
        expect(json['locktime'], policy.locktime);
      });

      test('Policy.fromJson restores the legacy policy and its script', () {
        final Policy restored = Policy.fromJson(policy.toJson());

        expect(restored, isA<LegacyInheritancePolicy>());
        expect(restored.toScript(0).rawSerialize(),
            policy.toScript(0).rawSerialize());
      });

      test('LegacyInheritancePolicy.fromJson restores locktime and key', () {
        final LegacyInheritancePolicy restored =
            LegacyInheritancePolicy.fromJson(policy.toJson());

        expect(restored.locktime, policy.locktime);
        expect(restored.beneficiaryKeyStore.masterFingerprint,
            policy.beneficiaryKeyStore.masterFingerprint);
      });
    });

    group('InheritancePolicy.toLegacy', () {
      test('keeps beneficiary and locktime and switches to DROP', () {
        final InheritancePolicy standard =
            InheritancePolicy(beneficiaryVault.keyStoreList[0], 1000);
        final LegacyInheritancePolicy legacy = standard.toLegacy();

        expect(legacy.locktime, 1000);
        expect(legacy.beneficiaryKeyStore, standard.beneficiaryKeyStore);
        expect(Codec.decodeHex(legacy.toScript(0).rawSerialize())[6], 0x75);
        expect(Codec.decodeHex(standard.toScript(0).rawSerialize())[6], 0x69);
      });
    });

    group('in a vault', () {
      test('a legacy leaf derives a different address than the standard one',
          () {
        final KeyStore parent = beneficiaryVault.keyStoreList[0];
        final TaprootVault legacyVault =
            TaprootVault.fromKeyStoreList([parent], [policy]);
        final TaprootVault standardVault = TaprootVault.fromKeyStoreList(
            [parent], [InheritancePolicy(parent, policy.locktime)]);

        expect(legacyVault.getAddress(0), isNot(standardVault.getAddress(0)));
      });

      test('JSON round trip keeps the legacy address', () {
        final TaprootVault vault = TaprootVault.fromKeyStoreList(
            [beneficiaryVault.keyStoreList[0]], [policy]);
        final TaprootVault restored = TaprootVault.fromJson(vault.toJson());

        expect(restored.getAddress(0), vault.getAddress(0));
      });

      test('descriptor round trip keeps the legacy address', () {
        final TaprootVault vault = TaprootVault.fromKeyStoreList(
            [beneficiaryVault.keyStoreList[0]], [policy]);
        final TaprootVault restored =
            TaprootVault.fromDescriptor(vault.descriptor);

        expect(restored.policyList[0], isA<LegacyInheritancePolicy>());
        expect(restored.getAddress(0), vault.getAddress(0));
      });
    });
  });
}
