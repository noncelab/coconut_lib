@Tags(['unit'])
library;

import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

void main() {
  group('MultisignatureScript', () {
    group('MultisignatureScript.parse', () {
      test('Generate multisignature script from parse', () {
        String witnessScriptText =
            '695221028106e5b5449e0b78e7e06c6435f724b9797db0926ed3ba59b01d6e3dee8fd74b2102869102bed3322707dfebeaf06f9e0f89b5d133e48ee481bcd624dfc1fa1b18802102d6481c1e9ead3f86508ec5d4b515089ae40505f642901e078824184e910d336353ae';
        MultisignatureScript witnessScript =
            MultisignatureScript.parse(witnessScriptText);
        expect(witnessScript.getPublicKeys().length, 3);
      });

      String serializeCommands(List<dynamic> commands) =>
          Script(commands).serialize();

      test('rejects a script without OP_CHECKMULTISIG', () {
        expect(() => MultisignatureScript.parse(serializeCommands([0x51])),
            throwsFormatException);
      });

      test('rejects an invalid signer count', () {
        expect(
            () => MultisignatureScript.parse(
                serializeCommands([0x51, 0x50, 0xae])),
            throwsFormatException);
      });

      test('rejects a signer count that differs from key count', () {
        final key = Uint8List.fromList(List<int>.filled(33, 2));
        expect(
            () => MultisignatureScript.parse(
                serializeCommands([0x51, key, 0x52, 0xae])),
            throwsFormatException);
      });

      test('rejects a signature threshold greater than signer count', () {
        final key = Uint8List.fromList(List<int>.filled(33, 2));
        expect(
            () => MultisignatureScript.parse(
                serializeCommands([0x52, key, 0x51, 0xae])),
            throwsFormatException);
      });

      test('rejects invalid public key lengths', () {
        final key = Uint8List.fromList(List<int>.filled(32, 2));
        expect(
            () => MultisignatureScript.parse(
                serializeCommands([0x51, key, 0x51, 0xae])),
            throwsFormatException);
      });

      test('rejects public keys outside lexicographical order', () {
        final high = Uint8List.fromList([3, ...List<int>.filled(32, 1)]);
        final low = Uint8List.fromList([2, ...List<int>.filled(32, 1)]);
        expect(
            () => MultisignatureScript.parse(
                serializeCommands([0x51, high, low, 0x52, 0xae])),
            throwsFormatException);
      });
    });
    group('MultisignatureScript.forP2wsh', () {
      test('Generate multisignature script for p2wsh', () {
        List<Uint8List> publicKeys = [
          Codec.decodeHex(
              '028106e5b5449e0b78e7e06c6435f724b9797db0926ed3ba59b01d6e3dee8fd74b'),
          Codec.decodeHex(
              '02869102bed3322707dfebeaf06f9e0f89b5d133e48ee481bcd624dfc1fa1b1880'),
          Codec.decodeHex(
              '02d6481c1e9ead3f86508ec5d4b515089ae40505f642901e078824184e910d3363')
        ];
        MultisignatureScript multisignatureScript =
            MultisignatureScript.forP2wsh(2, 3, publicKeys);
        expect(multisignatureScript.commands[0], 0x52);
        // expect(Converter.bytesToHex(multisignatureScript.commands[1]),
        //     publicKeys[0]);
        // expect(Converter.bytesToHex(multisignatureScript.commands[2]),
        //     publicKeys[1]);
        expect(multisignatureScript.commands[1], publicKeys[0]);
        expect(multisignatureScript.commands[2], publicKeys[1]);
        expect(multisignatureScript.commands[3], publicKeys[2]);
        expect(multisignatureScript.commands[4], 0x53);
        expect(multisignatureScript.commands[5], 0xae);
      });

      test('uses key length as a sorting tie-breaker', () {
        final short = Uint8List.fromList([2]);
        final long = Uint8List.fromList([2, 0]);
        final script = MultisignatureScript.forP2wsh(1, 2, [long, short]);
        expect(script.commands[1], short);
        expect(script.commands[2], long);
      });

      test('rejects duplicate public keys and invalid threshold', () {
        final publicKey = Uint8List.fromList([2, ...List<int>.filled(32, 1)]);

        expect(
            () => MultisignatureScript.forP2wsh(1, 2, [publicKey, publicKey]),
            throwsException);
        expect(() => MultisignatureScript.forP2wsh(0, 1, [publicKey]),
            throwsException);
        expect(() => MultisignatureScript.forP2wsh(2, 1, [publicKey]),
            throwsException);
      });
    });
    group('getRequiredSignature', () {
      test('Get reqruied signature', () {
        List<Uint8List> publicKeys = [
          Codec.decodeHex(
              '028106e5b5449e0b78e7e06c6435f724b9797db0926ed3ba59b01d6e3dee8fd74b'),
          Codec.decodeHex(
              '02869102bed3322707dfebeaf06f9e0f89b5d133e48ee481bcd624dfc1fa1b1880'),
          Codec.decodeHex(
              '02d6481c1e9ead3f86508ec5d4b515089ae40505f642901e078824184e910d3363')
        ];
        MultisignatureScript multisignatureScript =
            MultisignatureScript.forP2wsh(2, 3, publicKeys);
        expect(multisignatureScript.getRequiredSignature(), 2);
      });

      test('throws when the first opcode is not a signature count', () {
        final script = MultisignatureScript([0xae]);
        expect(script.getRequiredSignature, throwsException);
      });
    });
    group('getPublicKeys', () {
      test('Get public key list', () {
        List<Uint8List> publicKeys = [
          Codec.decodeHex(
              '028106e5b5449e0b78e7e06c6435f724b9797db0926ed3ba59b01d6e3dee8fd74b'),
          Codec.decodeHex(
              '02869102bed3322707dfebeaf06f9e0f89b5d133e48ee481bcd624dfc1fa1b1880'),
          Codec.decodeHex(
              '02d6481c1e9ead3f86508ec5d4b515089ae40505f642901e078824184e910d3363')
        ];
        MultisignatureScript multisignatureScript =
            MultisignatureScript.forP2wsh(2, 3, publicKeys);
        expect(multisignatureScript.getPublicKeys(), publicKeys);
      });
    });
  });
}
