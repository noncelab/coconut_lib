@Tags(['unit'])
library;

import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('MultisignaturePolicy', () {
    late List<KeyStore> keyStores;

    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
      keyStores = ['A', 'B', 'C']
          .map((passphrase) =>
              WalletFixture.beneficiaryVault(passphrase: passphrase)
                  .keyStoreList[0])
          .toList();
    });

    group('constructor', () {
      test('accepts thresholds within 1..n', () {
        expect(MultisignaturePolicy(keyStores, 1).requiredSignature, 1);
        expect(MultisignaturePolicy(keyStores, 3).requiredSignature, 3);
        expect(MultisignaturePolicy(keyStores, 2).totalSigner, 3);
      });

      test('rejects thresholds outside 1..n', () {
        expect(() => MultisignaturePolicy(keyStores, 0), throwsRangeError);
        expect(() => MultisignaturePolicy(keyStores, 4), throwsRangeError);
      });

      test('rejects an empty signer set', () {
        expect(() => MultisignaturePolicy([], 1), throwsArgumentError);
      });

      test('rejects duplicate public keys', () {
        expect(() => MultisignaturePolicy([keyStores[0], keyStores[0]], 2),
            throwsArgumentError);
      });

      test('copies the signer list', () {
        final List<KeyStore> source = List<KeyStore>.of(keyStores);
        final MultisignaturePolicy p = MultisignaturePolicy(source, 2);
        source.clear();
        expect(p.totalSigner, 3);
      });
    });

    group('fromDescriptor', () {
      test('creates policy from a taproot multikey descriptor', () {
        final TaprootVault multikeyVault = WalletFixture.p2trMultikeyVault();
        final MultisignaturePolicy p =
            MultisignaturePolicy.fromDescriptor(multikeyVault.descriptor, 2);
        expect(p.totalSigner, multikeyVault.keyStoreList.length);
        expect(p.requiredSignature, 2);
      });

      test('throws when descriptor is not taproot', () {
        final MultisignatureVault p2wsh = WalletFixture.p2wshVault();
        expect(() => MultisignaturePolicy.fromDescriptor(p2wsh.descriptor, 2),
            throwsException);
      });

      test('throws when descriptor embeds tap scripts', () {
        final TaprootVault vaultWithScripts = WalletFixture.p2trPolicyVault();
        expect(
            () => MultisignaturePolicy.fromDescriptor(
                vaultWithScripts.descriptor, 2),
            throwsException);
      });
    });

    group('toScript', () {
      test('encodes multi_a: CHECKSIG, CHECKSIGADD per extra key, NUMEQUAL',
          () {
        final Script s = MultisignaturePolicy(keyStores, 2).toScript(0);

        // 3 keys => 3 pushes + 3 sig opcodes + threshold + NUMEQUAL
        expect(s.commands.length, 8);
        expect((s.commands[0] as Uint8List).length, 32);
        expect(s.commands[1], ScriptOperationCode.getHex('OP_CHECKSIG'));
        expect((s.commands[2] as Uint8List).length, 32);
        expect(s.commands[3], ScriptOperationCode.getHex('OP_CHECKSIGADD'));
        expect((s.commands[4] as Uint8List).length, 32);
        expect(s.commands[5], ScriptOperationCode.getHex('OP_CHECKSIGADD'));
        expect(s.commands[6], ScriptOperationCode.getHex('OP_2'));
        expect(s.commands[7], ScriptOperationCode.getHex('OP_NUMEQUAL'));
      });

      test('ends with OP_NUMEQUAL (0x9c), not OP_EQUAL (0x87)', () {
        final String raw = MultisignaturePolicy(keyStores, 2)
            .toScript(0)
            .rawSerialize()
            .toLowerCase();
        expect(raw, endsWith('529c')); // OP_2 OP_NUMEQUAL
      });

      test('never emits the tapscript-disabled OP_CHECKMULTISIG', () {
        final Script s = MultisignaturePolicy(keyStores, 2).toScript(0);
        expect(s.commands,
            isNot(contains(ScriptOperationCode.getHex('OP_CHECKMULTISIG'))));
      });

      test('preserves the given key order', () {
        final MultisignaturePolicy ordered = MultisignaturePolicy(keyStores, 2);
        final MultisignaturePolicy reversed =
            MultisignaturePolicy(keyStores.reversed.toList(), 2);
        expect(ordered.toScript(0).rawSerialize(),
            isNot(reversed.toScript(0).rawSerialize()));
      });
    });

    group('toMiniscript', () {
      test('uses the canonical multi_a expression', () {
        final String miniscript =
            MultisignaturePolicy(keyStores, 2).toMiniscript();
        expect(miniscript, startsWith('multi_a(2,'));
        for (KeyStore keyStore in keyStores) {
          expect(miniscript, contains(keyStore.masterFingerprint));
        }
      });
    });

    group('fromMiniscript', () {
      test('roundtrips threshold, signers and order', () {
        final MultisignaturePolicy original =
            MultisignaturePolicy(keyStores, 2);
        final Policy parsed =
            MultisignaturePolicy.fromMiniscript(original.toMiniscript());
        expect(parsed, isA<MultisignaturePolicy>());
        final MultisignaturePolicy mp = parsed as MultisignaturePolicy;
        expect(mp.requiredSignature, 2);
        expect(mp.keyStoreList.map((k) => k.masterFingerprint).toList(),
            keyStores.map((k) => k.masterFingerprint).toList());
        expect(mp.getTapleafHash(0), original.getTapleafHash(0));
      });

      test('rejects a malformed key origin expression', () {
        expect(() => MultisignaturePolicy.fromMiniscript('multi_a(2,k1,k2)'),
            throwsFormatException);
      });

      test('rejects an expression that is not multi_a()', () {
        expect(
            () => MultisignaturePolicy.fromMiniscript(
                MultisignaturePolicy(keyStores, 2)
                    .toMiniscript()
                    .replaceFirst('multi_a(', 'sortedmulti_a(')),
            throwsFormatException);
      });
    });

    group('fromJson', () {
      test('restores threshold and signers', () {
        final MultisignaturePolicy original =
            MultisignaturePolicy(keyStores, 2);
        final MultisignaturePolicy restored =
            MultisignaturePolicy.fromJson(original.toJson());
        expect(restored.requiredSignature, original.requiredSignature);
        expect(restored.keyStoreList.map((k) => k.masterFingerprint).toList(),
            original.keyStoreList.map((k) => k.masterFingerprint).toList());
        expect(restored.toMiniscript(), original.toMiniscript());
      });

      test('throws when the signer list holds non-string entries', () {
        expect(
            () => MultisignaturePolicy.fromJson(
                '{"type":"multisignature","requiredSignature":2,"keyStoreList":[1,2]}'),
            throwsFormatException);
      });

      test('throws when the threshold is missing', () {
        expect(
            () => MultisignaturePolicy.fromJson(
                '{"type":"multisignature","keyStoreList":[]}'),
            throwsFormatException);
      });
    });
  });
}
