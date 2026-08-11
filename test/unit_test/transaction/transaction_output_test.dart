@Tags(['unit'])

import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:bech32/bech32.dart';
import 'package:test/test.dart';

String _witnessV0Address(int programLength) {
  final program = Uint8List(programLength);
  final data = Converter.convertBits(program, 8, 5, pad: true);
  return Bech32Codec().encode(Bech32('bc', [0, ...data]));
}

void main() {
  group('TransactionOutput', () {
    group('amount', () {
      test('Get amont from transaction output', () {
        String address = 'bc1qkfr6qzkvrnpvpd97p57r3krxl8qg6fz24nzjsa';
        int amount = 1000;
        TransactionOutput output =
            TransactionOutput.forPayment(amount, address);
        expect(output.amount, amount);
      });
    });
    group('scriptPubKey', () {
      test('Get script public key', () {
        String address = 'bc1qkfr6qzkvrnpvpd97p57r3krxl8qg6fz24nzjsa';
        int amount = 1000;
        TransactionOutput output =
            TransactionOutput.forPayment(amount, address);
        expect(output.scriptPubKey.serialize(),
            '160014b247a00acc1cc2c0b4be0d3c38d866f9c08d244a');
      });
    });
    group('length', () {
      test('Get length of transcation output', () {
        String address = 'bc1qkfr6qzkvrnpvpd97p57r3krxl8qg6fz24nzjsa';
        int amount = 1000;
        TransactionOutput output =
            TransactionOutput.forPayment(amount, address);
        expect(output.length, 31);
      });
    });
    group('isChangeOutput', () {
      test('Check if the output is a change output', () {
        String address = 'bc1qkfr6qzkvrnpvpd97p57r3krxl8qg6fz24nzjsa';
        int amount = 1000;
        TransactionOutput output =
            TransactionOutput.forPayment(amount, address);
        expect(output.isChangeOutput, false);
        output =
            TransactionOutput.forPayment(amount, address, isChangeOutput: true);
        expect(output.isChangeOutput, true);
      });
    });
    group('setAmount', () {
      test('Set amount of transaction output', () {
        String address = 'bc1qkfr6qzkvrnpvpd97p57r3krxl8qg6fz24nzjsa';
        int amount = 1000;
        TransactionOutput output =
            TransactionOutput.forPayment(amount, address);
        output.setAmount(2000);
        expect(output.amount, 2000);
      });

      test('Reject amounts outside the Bitcoin money range', () {
        const String address = 'bc1qkfr6qzkvrnpvpd97p57r3krxl8qg6fz24nzjsa';
        final TransactionOutput output =
            TransactionOutput.forPayment(1000, address);

        expect(() => output.setAmount(-1), throwsRangeError);
        expect(() => output.setAmount(TransactionOutput.maxMoney + 1),
            throwsRangeError);
      });
    });
    group('TransactionOutput.forPayment', () {
      test('Generate transaction output for payment', () {
        String address = 'bc1qkfr6qzkvrnpvpd97p57r3krxl8qg6fz24nzjsa';
        int amount = 1000;
        TransactionOutput output =
            TransactionOutput.forPayment(amount, address);
        expect(output, isA<TransactionOutput>());
      });

      test('Reject negative and over-MAX_MONEY payment amounts', () {
        const String address = 'bc1qkfr6qzkvrnpvpd97p57r3krxl8qg6fz24nzjsa';

        expect(
            () => TransactionOutput.forPayment(-1, address), throwsRangeError);
        expect(
            () => TransactionOutput.forPayment(
                TransactionOutput.maxMoney + 1, address),
            throwsRangeError);
      });

      test('Accept 20-byte and 32-byte witness-v0 programs', () {
        expect(
            TransactionOutput.forPayment(1000, _witnessV0Address(20))
                .scriptPubKey
                .isP2wpkh(),
            true);
        expect(
            TransactionOutput.forPayment(1000, _witnessV0Address(32))
                .scriptPubKey
                .isP2wsh(),
            true);
      });

      test('Reject invalid witness-v0 program length', () {
        expect(() => TransactionOutput.forPayment(1000, _witnessV0Address(21)),
            throwsFormatException);
      });
    });
    group('isDustOutput', () {
      //   p2wpkh 294;
      //   p2wsh 354;
      //   p2sh 888;
      //   p2wpkhInP2sh 273;
      test('Check dust in P2PKH (false)', () {
        TransactionOutput output = TransactionOutput.forPayment(
            1000, '1JDbm94jodpi7rek4p6oXYJMUEyA8zCJEG');
        expect(output.isDustOutput(AddressType.p2pkh.isSegwit), false);
      });
      test('Check dust in P2PKH (true)', () {
        int threshold = 546;
        TransactionOutput output = TransactionOutput.forPayment(
            threshold, '1JDbm94jodpi7rek4p6oXYJMUEyA8zCJEG');
        expect(output.isDustOutput(AddressType.p2pkh.isSegwit), true);
      });
      test('Check dust in P2WPKH (false)', () {
        TransactionOutput output = TransactionOutput.forPayment(
            1000, 'bc1qjkyj7gr5sr80lzqjvp000kj4zer8uv5348wxft');
        expect(output.isDustOutput(AddressType.p2wpkh.isSegwit), false);
      });
      test('Check dust in P2WPKH (true)', () {
        int threshold = 294;
        TransactionOutput output = TransactionOutput.forPayment(
            threshold, 'bc1qjkyj7gr5sr80lzqjvp000kj4zer8uv5348wxft');
        expect(output.isDustOutput(AddressType.p2wpkh.isSegwit), true);
      });
      test('Check in P2WSH (false)', () {
        TransactionOutput output = TransactionOutput.forPayment(1000,
            'bc1qwqdg6squsna38e46795at95yu9atm8azzmyvckulcc7kytlcckxswvvzej');
        expect(output.isDustOutput(AddressType.p2wsh.isSegwit), false);
      });
      test('Check in P2WSH (true)', () {
        int threshold = 330;
        TransactionOutput output = TransactionOutput.forPayment(threshold,
            'bc1qwqdg6squsna38e46795at95yu9atm8azzmyvckulcc7kytlcckxswvvzej');
        expect(output.isDustOutput(AddressType.p2wsh.isSegwit), true);
      });
    });
    group('TransactionOutput.parse', () {
      test('Reject invalid witness-v0 program length', () {
        final invalidProgram = List.filled(21, '00').join();
        expect(
            () => TransactionOutput.parse(
                '0000000000000000170015$invalidProgram'),
            throwsFormatException);
      });

      test('Generate transaction output from parser on p2pkh', () {
        String outputText =
            'e803000000000000160014b247a00acc1cc2c0b4be0d3c38d866f9c08d244a';
        TransactionOutput output = TransactionOutput.parse(outputText);
        expect(output.amount, 1000);
        expect(output.scriptPubKey.getAddress(),
            'tb1qkfr6qzkvrnpvpd97p57r3krxl8qg6fz2l4eptw');
      });
      test('Generate transaction output from parser on p2wpkh', () {
        String outputText =
            '277c5d000000000016001424b3e9491f3eadd9862389d98480acf89bdab078';
        TransactionOutput output = TransactionOutput.parse(outputText);
        expect(output.amount, 6126631);
        expect(output.scriptPubKey.getAddress(),
            'tb1qyje7jjgl86kanp3r38vcfq9vlzda4vrcj8cctu');
      });
    });
    group('serialize', () {
      test('Serialize transaction output', () {
        TransactionOutput output = TransactionOutput.forPayment(1000,
            'bc1qwqdg6squsna38e46795at95yu9atm8azzmyvckulcc7kytlcckxswvvzej');
        expect(output.serialize(),
            'e803000000000000220020701a8d401c84fb13e6baf169d59684e17abd9fa216c8cc5b9fc63d622ff8c58d');
      });
    });
    group('getAddress', () {
      test('Get address from transaction output', () {
        TransactionOutput output = TransactionOutput.forPayment(1000,
            'tb1qwqdg6squsna38e46795at95yu9atm8azzmyvckulcc7kytlcckxsey6dra');
        expect(output.getAddress(),
            'tb1qwqdg6squsna38e46795at95yu9atm8azzmyvckulcc7kytlcckxsey6dra');
      });
    });
    group('operator ==', () {
      test('Check the equality of transaction outputs', () {
        TransactionOutput targetOutput = TransactionOutput.forPayment(1000,
            'bc1qwqdg6squsna38e46795at95yu9atm8azzmyvckulcc7kytlcckxswvvzej');
        TransactionOutput matchedOutput = TransactionOutput.parse(
            'e803000000000000220020701a8d401c84fb13e6baf169d59684e17abd9fa216c8cc5b9fc63d622ff8c58d');
        expect(targetOutput == matchedOutput, true);
      });
    });
    group('hashCode', () {
      test('Get hash code', () {
        TransactionOutput targetOutput = TransactionOutput.forPayment(1000,
            'bc1qwqdg6squsna38e46795at95yu9atm8azzmyvckulcc7kytlcckxswvvzej');
        expect(targetOutput.hashCode, 369910355);
      });
    });
  });
}
