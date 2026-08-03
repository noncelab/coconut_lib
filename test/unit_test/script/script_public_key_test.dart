@Tags(['unit'])
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:bech32/bech32.dart';
import 'package:test/test.dart';

String _witnessV0Address(int programLength, {String hrp = 'tb'}) {
  final program = Uint8List(programLength);
  final data = Converter.convertBits(program, 8, 5, pad: true);
  return Bech32Codec().encode(Bech32(hrp, [0, ...data]));
}

void main() {
  group('ScriptPublicKey', () {
    group('ScriptPublicKey.parse', () {
      test('Generate script public key from parse', () {
        String scriptPubKey =
            '2200200d03b386199fc909ca35652f582a526c6b1c45a588d0843759915eb6a41528b7';
        ScriptPublicKey script = ScriptPublicKey.parse(scriptPubKey);
        expect(script, isA<ScriptPublicKey>());
        expect(script.length, 35);
        expect(script.commands.length, 2);
      });

      test('Reject witness-v0 programs other than 20 or 32 bytes', () {
        final invalidProgram = List.filled(21, '00').join();
        expect(() => ScriptPublicKey.parse('170015$invalidProgram'),
            throwsFormatException);
      });
    });
    group('ScriptPublicKey.p2pkh', () {
      test('Generate p2pkh script public key', () {
        ScriptPublicKey script =
            ScriptPublicKey.p2pkh('moRfJ2A2uSRMz4tzTrn5VyiUMSMNSHxbL5');
        expect(script.getAddress(), 'moRfJ2A2uSRMz4tzTrn5VyiUMSMNSHxbL5');
      });
    });
    group('ScriptPublicKey.p2sh', () {
      test('Generate p2sh script public key', () {
        ScriptPublicKey script =
            ScriptPublicKey.p2sh('2N2JD6wb56AfK4tfmM6PwdVmoYk2dCKf4Br');
        expect(script.getAddress(), '2N2JD6wb56AfK4tfmM6PwdVmoYk2dCKf4Br');
      });
    });
    group('ScriptPublicKey.p2wpkh', () {
      test('Generate p2wpkh script public key', () {
        ScriptPublicKey script = ScriptPublicKey.p2wpkh(
            'tb1qkgm3dcvrhgy5n32adjkzrglfg9mwa5gjmwt5ex');
        expect(
            script.getAddress(), 'tb1qkgm3dcvrhgy5n32adjkzrglfg9mwa5gjmwt5ex');
      });

      test('Reject non-20-byte witness program', () {
        expect(() => ScriptPublicKey.p2wpkh(_witnessV0Address(32)),
            throwsFormatException);
        expect(() => ScriptPublicKey.p2wpkh(_witnessV0Address(21)),
            throwsFormatException);
      });
    });
    group('ScriptPublicKey.p2wsh', () {
      test('Generate p2wsh script public key', () {
        ScriptPublicKey script = ScriptPublicKey.p2wsh(
            'tb1qd22redun2rm8mt4zxjazks5mr8dxxdjnk57hhgf2fw2ghmarjahqm9g672');
        expect(script.getAddress(),
            'tb1qd22redun2rm8mt4zxjazks5mr8dxxdjnk57hhgf2fw2ghmarjahqm9g672');
      });

      test('Reject non-32-byte witness program', () {
        expect(() => ScriptPublicKey.p2wsh(_witnessV0Address(20)),
            throwsFormatException);
        expect(() => ScriptPublicKey.p2wsh(_witnessV0Address(31)),
            throwsFormatException);
      });
    });
    group('ScriptPublicKey.p2tr', () {
      test('Generate p2tr script public key', () {
        ScriptPublicKey script = ScriptPublicKey.p2tr(
            'bc1pygap4c2n4ufddtte9jnf4ju4a8yj6mm0x3dgd3qmv5cvflp2xrasqk4x9z');
        expect(script.serialize(),
            '225120223a1ae153af12d6ad792ca69acb95e9c92d6f6f345a86c41b6530c4fc2a30fb');
      });
    });
    group('getAddress', () {
      test('Get p2wpkh address', () {
        String script = '160014cb325c29ac1d9f9c56ab77c7f659f6a304a7bd02';
        ScriptPublicKey scriptPubKey = ScriptPublicKey.parse(script);
        String address = scriptPubKey.getAddress();
        expect(address, 'tb1qeve9c2dvrk0ec44twlrlvk0k5vz200gz8pu2wn');
      });

      test('Get p2tr address', () {
        String scriptPubKey =
            '22512028d00add401c7cacf799aa43d074972518c7dcc02c6bac140316707096c38510';
        ScriptPublicKey script = ScriptPublicKey.parse(scriptPubKey);
        expect(script.getAddress(),
            'tb1p9rgq4h2qr372eaue4fpaqayhy5vv0hxq9346c9qrzec8p9krs5gqfj6h0c');
      });

      test('Get p2sh address', () {
        String scriptPubKey =
            '17a91414a6d9f1ce6e5392df68e987de44b303525cc08687';
        ScriptPublicKey script = ScriptPublicKey.parse(scriptPubKey);

        expect(script.getAddress(), '2Mu8RP9xjU7Ypaqt71343FAAN8W9zTcGYAW');
      });

      test('Get p2wsh address', () {
        String scriptPubKey =
            '2200200d03b386199fc909ca35652f582a526c6b1c45a588d0843759915eb6a41528b7';
        ScriptPublicKey script = ScriptPublicKey.parse(scriptPubKey);

        expect(script.getAddress(),
            'tb1qp5pm8psenlysnj34v5h4s2jjd343c3d93rgggd6ej90tdfq49zms6sye4h');
      });
    });

    group('isP2wpkh', () {
      test('identifies only P2WPKH scripts', () {
        final ScriptPublicKey p2wpkh = ScriptPublicKey.parse(
            '160014cb325c29ac1d9f9c56ab77c7f659f6a304a7bd02');
        final ScriptPublicKey p2wsh = ScriptPublicKey.parse(
            '2200200d03b386199fc909ca35652f582a526c6b1c45a588d0843759915eb6a41528b7');
        expect(p2wpkh.isP2wpkh(), true);
        expect(p2wsh.isP2wpkh(), false);
      });
    });

    group('isP2wsh', () {
      test('identifies only P2WSH scripts', () {
        final ScriptPublicKey p2wsh = ScriptPublicKey.parse(
            '2200200d03b386199fc909ca35652f582a526c6b1c45a588d0843759915eb6a41528b7');
        final ScriptPublicKey p2tr = ScriptPublicKey.parse(
            '22512028d00add401c7cacf799aa43d074972518c7dcc02c6bac140316707096c38510');
        expect(p2wsh.isP2wsh(), true);
        expect(p2tr.isP2wsh(), false);
      });
    });

    group('isP2tr', () {
      test('identifies only P2TR scripts', () {
        final ScriptPublicKey p2wpkh = ScriptPublicKey.parse(
            '160014cb325c29ac1d9f9c56ab77c7f659f6a304a7bd02');
        final ScriptPublicKey p2tr = ScriptPublicKey.parse(
            '22512028d00add401c7cacf799aa43d074972518c7dcc02c6bac140316707096c38510');
        expect(p2tr.isP2tr(), true);
        expect(p2wpkh.isP2tr(), false);
      });
    });

    group('isP2pkh', () {
      test('identifies only P2PKH scripts', () {
        final ScriptPublicKey p2pkh =
            ScriptPublicKey.p2pkh('moRfJ2A2uSRMz4tzTrn5VyiUMSMNSHxbL5');
        final ScriptPublicKey p2sh =
            ScriptPublicKey.p2sh('2N2JD6wb56AfK4tfmM6PwdVmoYk2dCKf4Br');
        expect(p2pkh.isP2pkh(), true);
        expect(p2sh.isP2pkh(), false);
      });
    });

    group('isP2sh', () {
      test('identifies P2SH scripts', () {
        final ScriptPublicKey p2sh =
            ScriptPublicKey.p2sh('2N2JD6wb56AfK4tfmM6PwdVmoYk2dCKf4Br');
        expect(p2sh.isP2sh(), true);
      });
    });
  });
}
