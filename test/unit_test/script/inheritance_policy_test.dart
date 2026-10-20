@Tags(['unit'])
library;

import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('InheritancePolicy', () {
    late TaprootVault beneficiaryVault;

    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
      beneficiaryVault = WalletFixture.beneficiaryVault(passphrase: 'B');
    });

    group('constructor', () {
      test('accepts ScriptNum locktime boundaries', () {
        final KeyStore keyStore = beneficiaryVault.keyStoreList[0];

        expect(InheritancePolicy(keyStore, 0).locktime, 0);
        expect(
            InheritancePolicy(keyStore, InheritancePolicy.maxLocktime).locktime,
            InheritancePolicy.maxLocktime);
      });

      test('rejects locktime outside the supported ScriptNum range', () {
        final KeyStore keyStore = beneficiaryVault.keyStoreList[0];

        expect(() => InheritancePolicy(keyStore, -1), throwsRangeError);
        expect(
            () =>
                InheritancePolicy(keyStore, InheritancePolicy.maxLocktime + 1),
            throwsRangeError);
      });
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
        final SingleSignatureVault p2wpkh = WalletFixture.p2wpkhVault();
        expect(
            () => InheritancePolicy.fromDescriptorAndLocktime(
                p2wpkh.descriptor, 1),
            throwsException);
      });

      test('throws when descriptor embeds tap scripts', () {
        final TaprootVault vaultWithScripts = WalletFixture.p2trPolicyVault();
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

      test('rejects relative older expression', () {
        final InheritancePolicy original =
            InheritancePolicy.fromDescriptorAndLocktime(
                beneficiaryVault.descriptor, 987654321);
        final String canonical = original.toMiniscript();
        final String legacy = canonical.replaceFirst('after(', 'older(');
        expect(() => InheritancePolicy.fromMiniscript(legacy),
            throwsFormatException);
      });

      test('still parses the legacy and_v(v:pk,after) spelling', () {
        final InheritancePolicy original =
            InheritancePolicy.fromDescriptorAndLocktime(
                beneficiaryVault.descriptor, 987654321);
        final String legacy = _legacySpellingOf(original);

        final Policy parsed = InheritancePolicy.fromMiniscript(legacy);
        expect(parsed, isA<InheritancePolicy>());
        expect((parsed as InheritancePolicy).locktime, original.locktime);
        expect(parsed.beneficiaryKeyStore.masterFingerprint,
            original.beneficiaryKeyStore.masterFingerprint);
        // Read either way, written the standard way.
        expect(parsed.toMiniscript(), original.toMiniscript());
        expect(Policy.fromMiniscript(legacy), isA<InheritancePolicy>());
      });

      test('both spellings give the same leaf', () {
        final InheritancePolicy original =
            InheritancePolicy.fromDescriptorAndLocktime(
                beneficiaryVault.descriptor, 987654321);

        expect(
            InheritancePolicy.fromMiniscript(original.toMiniscript())
                .getTapleafHash(0),
            InheritancePolicy.fromMiniscript(_legacySpellingOf(original))
                .getTapleafHash(0));
      });
    });

    group('toMiniscript', () {
      test('uses the canonical after expression', () {
        final policy = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 987654321);
        expect(policy.toMiniscript(), contains('after(987654321)'));
        expect(policy.toMiniscript(), isNot(contains('older(')));
      });

      test('spells the timelock before the key, matching toScript', () {
        final policy = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 987654321);
        // and_v(v:after(N),pk(K)) compiles to <N> CLTV VERIFY <K> CHECKSIG.
        // The reverse spelling is a different script, so a wallet reading the
        // descriptor would derive a different leaf and a different address.
        expect(policy.toMiniscript(), startsWith('and_v(v:after(987654321),'));
        expect(policy.toMiniscript(), isNot(contains('v:pk(')));
      });

      test('compiles to the same bytes toScript emits', () {
        final policy = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 987654321);

        // Compile the miniscript independently, from the fragment rules only,
        // rather than trusting the library's own script builder.
        final RegExpMatch m = RegExp(r'^and_v\(v:after\((\d+)\),pk\((.+)\)\)$')
            .firstMatch(policy.toMiniscript())!;
        final int locktime = int.parse(m.group(1)!);
        final Uint8List pubkey =
            TaprootWallet.fromKeyOriginExpression(m.group(2)!)
                .keyStoreList[0]
                .getPublicKeyBytes(0, isXOnly: true);

        final List<int> compiled = [
          // v:after(N) -> <N> CHECKLOCKTIMEVERIFY VERIFY
          4, ...Converter.intToLittleEndianBytes(locktime, 4),
          ScriptOperationCode.getHex('OP_CHECKLOCKTIMEVERIFY'),
          ScriptOperationCode.getHex('OP_VERIFY'),
          // pk(K) -> <K> CHECKSIG
          32, ...pubkey,
          ScriptOperationCode.getHex('OP_CHECKSIG'),
        ];

        expect(policy.toScript(0).rawSerialize(),
            Codec.encodeHex(Uint8List.fromList(compiled)));
      });
    });

    group('toScript', () {
      test('encodes CLTV + VERIFY + x-only pubkey + CHECKSIG', () {
        final InheritancePolicy p = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 1000);
        final Script s = p.toScript(0);
        expect(s.commands.length, 5);
        expect(s.commands[1],
            ScriptOperationCode.getHex('OP_CHECKLOCKTIMEVERIFY'));
        expect(s.commands[2], ScriptOperationCode.getHex('OP_VERIFY'));
        expect(s.commands[3], isA<Uint8List>());
        expect((s.commands[3] as Uint8List).length, 32);
        expect(s.commands[4], ScriptOperationCode.getHex('OP_CHECKSIG'));
      });
    });

    group('toLegacy().toScript', () {
      test('encodes CLTV + DROP + x-only pubkey + CHECKSIG', () {
        final InheritancePolicy p = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 1000);
        final Script s = p.toLegacy().toScript(0);
        expect(s.commands.length, 5);
        expect(s.commands[1],
            ScriptOperationCode.getHex('OP_CHECKLOCKTIMEVERIFY'));
        expect(s.commands[2], ScriptOperationCode.getHex('OP_DROP'));
        expect(s.commands[3], (p.toScript(0).commands[3] as Uint8List));
        expect(s.commands[4], ScriptOperationCode.getHex('OP_CHECKSIG'));
      });

      test('differs from toScript only in the cleanup opcode', () {
        final InheritancePolicy p = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 1000);
        final String standard = p.toScript(0).rawSerialize();
        final String legacy = p.toLegacy().toScript(0).rawSerialize();
        expect(legacy, isNot(standard));
        expect(legacy.replaceFirst('75', '69'), standard);
      });
    });

    group('toScript / toLegacy().toScript bytes', () {
      List<int> expectedLeaf(int locktime, Uint8List pubkey, int cleanupOp) => [
            4, ...Converter.intToLittleEndianBytes(locktime, 4), // <N>
            0xb1, // OP_CHECKLOCKTIMEVERIFY
            cleanupOp,
            32, ...pubkey, // <K>
            0xac, // OP_CHECKSIG
          ];

      test('toScript emits CLTV VERIFY (0x69) as raw bytes', () {
        final InheritancePolicy p = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 1767225600);
        final Uint8List pubkey = beneficiaryVault.keyStoreList[0]
            .getPublicKeyBytes(0, isXOnly: true);

        expect(
            p.toScript(0).rawSerialize(),
            Codec.encodeHex(
                Uint8List.fromList(expectedLeaf(1767225600, pubkey, 0x69))));
      });

      test('toLegacy().toScript emits CLTV DROP (0x75) as raw bytes', () {
        final InheritancePolicy p = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 1767225600);
        final Uint8List pubkey = beneficiaryVault.keyStoreList[0]
            .getPublicKeyBytes(0, isXOnly: true);

        expect(
            p.toLegacy().toScript(0).rawSerialize(),
            Codec.encodeHex(
                Uint8List.fromList(expectedLeaf(1767225600, pubkey, 0x75))));
      });

      test('both follow address index and change branch', () {
        final InheritancePolicy p = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 1000);

        for (final bool isChange in [false, true]) {
          for (final int index in [0, 1, 7]) {
            final Uint8List pubkey = beneficiaryVault.keyStoreList[0]
                .getPublicKeyBytes(index, isChange: isChange, isXOnly: true);
            expect(
                p.toScript(index, isChange: isChange).rawSerialize(),
                Codec.encodeHex(
                    Uint8List.fromList(expectedLeaf(1000, pubkey, 0x69))));
            expect(
                p.toLegacy().toScript(index, isChange: isChange).rawSerialize(),
                Codec.encodeHex(
                    Uint8List.fromList(expectedLeaf(1000, pubkey, 0x75))));
          }
        }
      });

      test('differ only in the cleanup opcode, for any locktime', () {
        for (final int locktime in [0, 1, 1000, 1767225600, 0x7fffffff]) {
          final InheritancePolicy p =
              InheritancePolicy(beneficiaryVault.keyStoreList[0], locktime);
          final List<int> standard =
              Codec.decodeHex(p.toScript(0).rawSerialize());
          final List<int> legacy =
              Codec.decodeHex(p.toLegacy().toScript(0).rawSerialize());

          expect(legacy.length, standard.length);
          final List<int> diff = [
            for (int i = 0; i < standard.length; i++)
              if (standard[i] != legacy[i]) i
          ];
          expect(diff, [6]); // 1 + 4 (push N) + 1 (CLTV) -> cleanup opcode
          expect(standard[6], 0x69);
          expect(legacy[6], 0x75);
        }
      });

      test('toMiniscript describes the standard script, not the legacy one',
          () {
        final InheritancePolicy p = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 1000);

        final InheritancePolicy restored =
            InheritancePolicy.fromMiniscript(p.toMiniscript())
                as InheritancePolicy;
        expect(
            restored.toScript(0).rawSerialize(), p.toScript(0).rawSerialize());
        expect(restored.toScript(0).rawSerialize(),
            isNot(p.toLegacy().toScript(0).rawSerialize()));
      });
    });

    group('tapleaf hash', () {
      Uint8List leafHash(String rawScriptHex) {
        final Uint8List script = Codec.decodeHex(rawScriptHex);
        return Hash.taggedHash(
            'TapLeaf', Uint8List.fromList([0xc0, script.length, ...script]));
      }

      test('getTapleafHash commits to the toScript (VERIFY) leaf', () {
        final InheritancePolicy p = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 1000);

        expect(p.getTapleafHash(0), leafHash(p.toScript(0).rawSerialize()));
      });

      test('the legacy leaf hashes to a different tapleaf', () {
        final InheritancePolicy p = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 1000);

        expect(leafHash(p.toLegacy().toScript(0).rawSerialize()),
            isNot(p.getTapleafHash(0)));
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

/// The spelling earlier versions emitted, rebuilt from the standard one.
String _legacySpellingOf(InheritancePolicy policy) {
  final RegExpMatch match = RegExp(r'^and_v\(v:after\((\d+)\),pk\((.+)\)\)$')
      .firstMatch(policy.toMiniscript())!;
  return 'and_v(v:pk(${match.group(2)}),after(${match.group(1)}))';
}
