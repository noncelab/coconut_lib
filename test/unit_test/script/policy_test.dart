@Tags(['unit'])
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../mock_factory.dart';

class _FakePolicy extends Policy {
  final int scriptLen;
  _FakePolicy(this.scriptLen);

  @override
  Script toScript(int addressIndex, {bool isChange = false}) {
    // Build raw script with exact length using opcodes only.
    return Script(List<int>.filled(scriptLen, 0x51));
  }

  @override
  String toMiniscript() => 'fake($scriptLen)';

  @override
  String toJson() => jsonEncode({'type': 'fake', 'len': scriptLen});
}

void main() {
  group('Policy', () {
    late TaprootVault beneficiaryVault;
    late InheritancePolicy inheritancePolicy;

    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
      beneficiaryVault = MockFactory.createBeneficiaryVault(passphrase: 'A');
      inheritancePolicy = InheritancePolicy.fromDescriptorAndLocktime(
          beneficiaryVault.descriptor, 1798761600);
    });

    group('fromMiniscript', () {
      test('parses inheritance miniscript', () {
        final Policy p =
            Policy.fromMiniscript(inheritancePolicy.toMiniscript());
        expect(p, isA<InheritancePolicy>());
        expect((p as InheritancePolicy).locktime, inheritancePolicy.locktime);
      });

      test('rejects relative older inheritance miniscript', () {
        final String relative =
            inheritancePolicy.toMiniscript().replaceFirst('after(', 'older(');
        expect(() => Policy.fromMiniscript(relative), throwsException);
      });

      test('throws for unsupported miniscript', () {
        expect(() => Policy.fromMiniscript('pk(k)'), throwsException);
      });
    });

    group('fromJson', () {
      test('deserializes typed inheritance policy JSON', () {
        final Policy p = Policy.fromJson(inheritancePolicy.toJson());
        expect(p, isA<InheritancePolicy>());
        final InheritancePolicy ip = p as InheritancePolicy;
        expect(ip.locktime, inheritancePolicy.locktime);
        expect(ip.beneficiaryKeyStore.masterFingerprint,
            inheritancePolicy.beneficiaryKeyStore.masterFingerprint);
      });

      test('deserializes legacy JSON with miniscript field only', () {
        final String legacy = jsonEncode(<String, String>{
          'miniscript': inheritancePolicy.toMiniscript(),
        });
        final Policy p = Policy.fromJson(legacy);
        expect(p, isA<InheritancePolicy>());
      });

      test('throws when type is unsupported', () {
        final String json = jsonEncode(<String, String>{
          'type': 'unknown_type',
          'dummy': 'x',
        });
        expect(() => Policy.fromJson(json), throwsFormatException);
      });

      test('throws when neither type nor miniscript present', () {
        expect(() => Policy.fromJson('{}'), throwsFormatException);
      });

      test('throws when JSON is not an object', () {
        expect(() => Policy.fromJson('[]'), throwsFormatException);
      });
    });

    group('getTapleafHash', () {
      test('returns 32-byte TapLeaf tagged hash', () {
        expect(inheritancePolicy.getTapleafHash(0).length, 32);
      });

      test('matches Policy restored from miniscript', () {
        final Policy restored =
            Policy.fromMiniscript(inheritancePolicy.toMiniscript());
        expect(restored.getTapleafHash(0), inheritancePolicy.getTapleafHash(0));
      });

      test('uses CompactSize 0xfd when script len > 252', () {
        final Policy p = _FakePolicy(300);
        final Uint8List scriptBytes =
            Uint8List.fromList(List.filled(300, 0x51));
        final Uint8List expected = Hash.taggedHash(
            'TapLeaf',
            Uint8List.fromList([
              0xc0,
              0xfd,
              0x2c,
              0x01,
              ...scriptBytes,
            ]));
        expect(p.getTapleafHash(0), expected);
      });

      test('uses CompactSize 0xfe when script len > 65535', () {
        final Policy p = _FakePolicy(70000);
        final Uint8List scriptBytes =
            Uint8List.fromList(List.filled(70000, 0x51));
        final Uint8List expected = Hash.taggedHash(
            'TapLeaf',
            Uint8List.fromList([
              0xc0,
              0xfe,
              0x70,
              0x11,
              0x01,
              0x00,
              ...scriptBytes,
            ]));
        expect(p.getTapleafHash(0), expected);
      });
    });
  });
}
