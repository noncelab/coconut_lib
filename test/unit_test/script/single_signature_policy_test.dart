@Tags(['unit'])
library;

import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('SingleSignaturePolicy', () {
    late TaprootVault vault;
    late KeyStore keyStore;

    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
      vault = WalletFixture.beneficiaryVault(passphrase: 'A');
      keyStore = vault.keyStoreList[0];
    });

    group('fromDescriptor', () {
      test('creates policy for taproot single signature descriptor', () {
        final SingleSignaturePolicy p =
            SingleSignaturePolicy.fromDescriptor(vault.descriptor);
        expect(p.keyStore.masterFingerprint, keyStore.masterFingerprint);
      });

      test('throws when descriptor is not taproot', () {
        final SingleSignatureVault p2wpkh = WalletFixture.p2wpkhVault();
        expect(() => SingleSignaturePolicy.fromDescriptor(p2wpkh.descriptor),
            throwsException);
      });

      test('throws when descriptor embeds tap scripts', () {
        final TaprootVault vaultWithScripts = WalletFixture.p2trPolicyVault();
        expect(
            () => SingleSignaturePolicy.fromDescriptor(
                vaultWithScripts.descriptor),
            throwsException);
      });
    });

    group('toScript', () {
      test('encodes x-only pubkey + CHECKSIG', () {
        final Script s = SingleSignaturePolicy(keyStore).toScript(0);
        expect(s.commands.length, 2);
        expect(s.commands[0], isA<Uint8List>());
        expect((s.commands[0] as Uint8List).length, 32);
        expect(s.commands[1], ScriptOperationCode.getHex('OP_CHECKSIG'));
      });

      test('derives a different key per address index and chain', () {
        final SingleSignaturePolicy p = SingleSignaturePolicy(keyStore);
        expect(
            p.toScript(0).rawSerialize(), isNot(p.toScript(1).rawSerialize()));
        expect(p.toScript(0).rawSerialize(),
            isNot(p.toScript(0, isChange: true).rawSerialize()));
      });
    });

    group('toMiniscript', () {
      test('uses the canonical pk expression', () {
        final String miniscript =
            SingleSignaturePolicy(keyStore).toMiniscript();
        expect(miniscript, startsWith('pk('));
        expect(miniscript, contains(keyStore.masterFingerprint));
      });
    });

    group('fromMiniscript', () {
      test('roundtrips key origin expression', () {
        final SingleSignaturePolicy original = SingleSignaturePolicy(keyStore);
        final Policy parsed =
            SingleSignaturePolicy.fromMiniscript(original.toMiniscript());
        expect(parsed, isA<SingleSignaturePolicy>());
        expect((parsed as SingleSignaturePolicy).keyStore.masterFingerprint,
            keyStore.masterFingerprint);
        expect(parsed.getTapleafHash(0), original.getTapleafHash(0));
      });

      test('rejects a malformed key origin expression', () {
        expect(() => SingleSignaturePolicy.fromMiniscript('pk(k)'),
            throwsFormatException);
      });

      test('rejects an expression that is not pk()', () {
        expect(
            () => SingleSignaturePolicy.fromMiniscript(
                'older(${SingleSignaturePolicy(keyStore).toMiniscript()})'),
            throwsFormatException);
      });
    });

    group('fromJson', () {
      test('restores the key store', () {
        final SingleSignaturePolicy original = SingleSignaturePolicy(keyStore);
        final SingleSignaturePolicy restored =
            SingleSignaturePolicy.fromJson(original.toJson());
        expect(restored.keyStore.masterFingerprint,
            original.keyStore.masterFingerprint);
        expect(restored.toMiniscript(), original.toMiniscript());
      });

      test('throws when the key store field is missing', () {
        expect(
            () => SingleSignaturePolicy.fromJson('{"type":"singleSignature"}'),
            throwsFormatException);
      });
    });
  });
}
