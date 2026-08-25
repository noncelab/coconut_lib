@Tags(['unit'])
library;

import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

void main() {
  group('ScriptSignature', () {
    group('ScriptSignature.parse', () {
      test('Generate script signature from parse', () {
        String scriptSigText =
            '6a4730440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be0012102742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8df';
        ScriptSignature script = ScriptSignature.parse(scriptSigText);

        expect(script, isA<ScriptSignature>());
        expect(script.length, 107);
        expect(script.commands.length, 2);
      });
    });
    group('ScriptSignature.p2pkh', () {
      test('Generate p2pkh script signature', () {
        Uint8List signature = Codec.decodeHex(
            '30440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be001');
        Uint8List publicKey = Codec.decodeHex(
            '02742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8df');
        ScriptSignature script = ScriptSignature.p2pkh(signature, publicKey);
        expect(script.length, 107);
        expect(script.commands[0], signature);
        expect(script.commands[1], publicKey);
      });
    });
    group('ScriptSignature.p2wpkh', () {
      test('Generate p2wpkh scipt signature', () {
        ScriptSignature script = ScriptSignature.p2wpkh();
        expect(script.length, 1);
        expect(script.commands[0], 0x00);
      });
    });
    group('ScriptSignature.p2wsh', () {
      test('Generate p2wsh scipt signature', () {
        ScriptSignature script = ScriptSignature.p2wsh();
        expect(script.length, 1);
        expect(script.commands[0], 0x00);
      });
    });
    group('ScriptSignature.empty', () {
      test('Generate empty scipt signature', () {
        ScriptSignature script = ScriptSignature.empty();
        expect(script.length, 1);
        expect(script.commands[0], 0x00);
      });
    });
  });
}
