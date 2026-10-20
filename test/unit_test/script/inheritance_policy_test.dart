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
      test('accepts the BIP-379 after(n) range 1 <= n < 2^31', () {
        final KeyStore keyStore = beneficiaryVault.keyStoreList[0];

        expect(
            InheritancePolicy(keyStore, InheritancePolicy.minLocktime).locktime,
            1);
        expect(
            InheritancePolicy(keyStore, InheritancePolicy.maxLocktime).locktime,
            InheritancePolicy.maxLocktime);
      });

      test('rejects locktime 0, which makes CLTV VERIFY unspendable', () {
        final KeyStore keyStore = beneficiaryVault.keyStoreList[0];

        expect(() => InheritancePolicy(keyStore, 0), throwsRangeError);
        expect(
            () => InheritancePolicy.fromDescriptorAndLocktime(
                beneficiaryVault.descriptor, 0),
            throwsRangeError);
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

      test('reads both spellings as the CLTV VERIFY leaf', () {
        final InheritancePolicy original =
            InheritancePolicy.fromDescriptorAndLocktime(
                beneficiaryVault.descriptor, 987654321);

        for (final String spelling in [
          original.toMiniscript(),
          _legacySpellingOf(original),
        ]) {
          final Policy parsed = Policy.fromMiniscript(spelling);

          expect(parsed, isA<InheritancePolicy>());
          expect(parsed, isNot(isA<LegacyInheritancePolicy>()));
          expect(parsed.toScript(0).rawSerialize(),
              original.toScript(0).rawSerialize());
          expect(Codec.decodeHex(parsed.toScript(0).rawSerialize())[6], 0x69);
        }
      });

      test('rejects after(0) and after(2^31)', () {
        final String body = _legacySpellingOf(
                InheritancePolicy.fromDescriptorAndLocktime(
                    beneficiaryVault.descriptor, 1000))
            .replaceFirst('after(1000)', 'after(0)');
        final String standard = InheritancePolicy.fromDescriptorAndLocktime(
                beneficiaryVault.descriptor, 1000)
            .toMiniscript();

        expect(() => Policy.fromMiniscript(body), throwsRangeError);
        expect(
            () => Policy.fromMiniscript(
                standard.replaceFirst('after(1000)', 'after(0)')),
            throwsRangeError);
        expect(
            () => Policy.fromMiniscript(
                standard.replaceFirst('after(1000)', 'after(2147483648)')),
            throwsRangeError);
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

      test('differs from toScript only in the cleanup opcode at four bytes',
          () {
        // 1767225600 needs four bytes as a script number, so both leaves push
        // it the same way.
        final InheritancePolicy p = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 1767225600);
        final String standard = p.toScript(0).rawSerialize();
        final String legacy = p.toLegacy().toScript(0).rawSerialize();
        expect(legacy, isNot(standard));
        expect(legacy.replaceFirst('75', '69'), standard);
      });
    });

    group('toScript / toLegacy().toScript bytes', () {
      // `<N>` as Bitcoin Core pushes it, written out by hand: OP_1..OP_16 for
      // 1..16, else the shortest little-endian number, plus a zero byte when
      // the top bit would read as a sign.
      const Map<int, List<int>> minimalPush = {
        1: [0x51],
        10: [0x5a],
        16: [0x60],
        17: [0x01, 0x11],
        127: [0x01, 0x7f],
        128: [0x02, 0x80, 0x00],
        144: [0x02, 0x90, 0x00],
        255: [0x02, 0xff, 0x00],
        256: [0x02, 0x00, 0x01],
        1000: [0x02, 0xe8, 0x03],
        32767: [0x02, 0xff, 0x7f],
        32768: [0x03, 0x00, 0x80, 0x00],
        52560: [0x03, 0x50, 0xcd, 0x00],
        900000: [0x03, 0xa0, 0xbb, 0x0d],
        8388607: [0x03, 0xff, 0xff, 0x7f],
        8388608: [0x04, 0x00, 0x00, 0x80, 0x00],
        1767225600: [0x04, 0x00, 0xb9, 0x55, 0x69],
        0x7fffffff: [0x04, 0xff, 0xff, 0xff, 0x7f],
      };

      List<int> standardLeaf(int locktime, Uint8List pubkey) => [
            ...minimalPush[locktime]!, // <N>
            0xb1, // OP_CHECKLOCKTIMEVERIFY
            0x69, // OP_VERIFY
            32, ...pubkey, // <K>
            0xac, // OP_CHECKSIG
          ];

      // The legacy leaf always pushes four bytes, as when it was funded.
      List<int> legacyLeaf(int locktime, Uint8List pubkey) => [
            4, ...Converter.intToLittleEndianBytes(locktime, 4), // <N>
            0xb1, // OP_CHECKLOCKTIMEVERIFY
            0x75, // OP_DROP
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
                Uint8List.fromList(standardLeaf(1767225600, pubkey))));
      });

      test('toLegacy().toScript emits CLTV DROP (0x75) as raw bytes', () {
        final InheritancePolicy p = InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault.descriptor, 1767225600);
        final Uint8List pubkey = beneficiaryVault.keyStoreList[0]
            .getPublicKeyBytes(0, isXOnly: true);

        expect(
            p.toLegacy().toScript(0).rawSerialize(),
            Codec.encodeHex(
                Uint8List.fromList(legacyLeaf(1767225600, pubkey))));
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
                    Uint8List.fromList(standardLeaf(1000, pubkey))));
            expect(
                p.toLegacy().toScript(index, isChange: isChange).rawSerialize(),
                Codec.encodeHex(Uint8List.fromList(legacyLeaf(1000, pubkey))));
          }
        }
      });

      test('toScript pushes the minimal script number for every locktime', () {
        final Uint8List pubkey = beneficiaryVault.keyStoreList[0]
            .getPublicKeyBytes(0, isXOnly: true);

        for (final int locktime in minimalPush.keys) {
          final InheritancePolicy p =
              InheritancePolicy(beneficiaryVault.keyStoreList[0], locktime);

          expect(
              p.toScript(0).rawSerialize(),
              Codec.encodeHex(
                  Uint8List.fromList(standardLeaf(locktime, pubkey))),
              reason: 'locktime $locktime');
        }
      });

      test('toLegacy().toScript keeps the four-byte push for every locktime',
          () {
        final Uint8List pubkey = beneficiaryVault.keyStoreList[0]
            .getPublicKeyBytes(0, isXOnly: true);

        for (final int locktime in minimalPush.keys) {
          final InheritancePolicy p =
              InheritancePolicy(beneficiaryVault.keyStoreList[0], locktime);

          expect(p.toLegacy().toScript(0).rawSerialize(),
              Codec.encodeHex(Uint8List.fromList(legacyLeaf(locktime, pubkey))),
              reason: 'locktime $locktime');
        }
      });

      test('a block-height locktime differs from the legacy leaf in the push',
          () {
        final InheritancePolicy p =
            InheritancePolicy(beneficiaryVault.keyStoreList[0], 900000);

        // 03 a0bb0d versus 04 a0bb0d00
        expect(p.toScript(0).rawSerialize().startsWith('03a0bb0db169'), isTrue);
        expect(
            p
                .toLegacy()
                .toScript(0)
                .rawSerialize()
                .startsWith('04a0bb0d00b175'),
            isTrue);
        expect(p.toScript(0).rawSerialize().length,
            lessThan(p.toLegacy().toScript(0).rawSerialize().length));
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
