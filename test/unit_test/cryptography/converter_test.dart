@Tags(['unit'])
library;

import 'dart:typed_data';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

void main() {
  group('Converter', () {
    group('decToHex', () {
      test('Get hexadecimal text from decimal', () {
        int decimalValue = 10;
        expect(Converter.decToHex(decimalValue), 'a');
      });
    });
    group('decToHexWithPadding', () {
      test('Get hexadecimal with padding from decimal', () {
        int decimalValue = 10;
        int padding = 5;
        expect(Converter.decToHexWithPadding(decimalValue, padding), '0000a');
      });
    });
    group('bigDecToHex', () {
      test('Get hexadecimal from big decimal', () {
        BigInt decimalValue = BigInt.parse('1000000000000000000000');
        expect(Converter.bigDecToHex(decimalValue), '3635c9adc5dea00000');
      });
    });
    group('bigIntToBytes', () {
      test('converts a big integer with and without fixed byte length', () {
        expect(Converter.bigIntToBytes(BigInt.from(0x1234)), [0x12, 0x34]);
        expect(Converter.bigIntToBytes(BigInt.from(0x1234), byteLength: 4),
            [0x00, 0x00, 0x12, 0x34]);
      });
    });
    group('decToBin', () {
      test('Get binary from decimal', () {
        int decimalValue = 10;
        expect(Converter.decToBin(decimalValue), '1010');
      });
    });
    group('hexToDec', () {
      test('Get decimal from hexadecimal', () {
        String hexString = 'a';
        expect(Converter.hexToDec(hexString), 10);
      });
    });
    group('hexToBigDec', () {
      test('converts hexadecimal larger than the integer range', () {
        expect(Converter.hexToBigDec('ffffffffffffffff'),
            BigInt.parse('18446744073709551615'));
      });
    });
    group('hexToBin', () {
      test('Get binary from hexadeciaml', () {
        String hexString = 'a';
        expect(Converter.hexToBin(hexString), '1010');
      });
    });
    group('binToDec', () {
      test('converts binary text to decimal', () {
        expect(Converter.binToDec('10101101'), 173);
      });
    });
    group('uint8ListToDec', () {
      test('converts big-endian bytes to decimal', () {
        expect(
            Converter.uint8ListToDec(Uint8List.fromList([0x01, 0x02])), 0x0102);
      });
    });
    group('binToHex', () {
      test('Get hexadecimal from binary', () {
        String binary = '1010';
        expect(Converter.binToHex(binary), 'A');
      });
      test('Reject invalid binary length', () {
        expect(() => Converter.binToHex('101'), throwsFormatException);
      });
    });
    group('binToBytes', () {
      test('Get bytes from binary', () {
        String binary = '10101101';
        expect(Converter.binToBytes(binary), [173]);
      });
    });
    group('bytesToDec', () {
      test('converts bytes to decimal', () {
        expect(Converter.bytesToDec(Uint8List.fromList([0x01, 0x02])), 0x0102);
      });
    });
    group('bytesToBinary', () {
      test('Get binary from bytes', () {
        List<int> bytes = [173];
        expect(Converter.bytesToBinary(Uint8List.fromList(bytes)),
            [1, 0, 1, 0, 1, 1, 0, 1]);
      });
    });
    group('binaryToDecimal', () {
      test('Get decimal from binary', () {
        List<int> binary = [1, 0, 1, 0, 1, 1, 0, 1];
        expect(Converter.binaryToDecimal(binary), 173);
      });
    });
    group('intToLittleEndianBytes', () {
      test('Get little endian from integer', () {
        int value = 10;
        expect(Converter.intToLittleEndianBytes(value, 4), [10, 0, 0, 0]);
      });
    });
    group('littleEndianToInt', () {
      test('Get integer from little endian', () {
        List<int> bytes = [10, 0, 0, 0];
        expect(Converter.littleEndianToInt(Uint8List.fromList(bytes)), 10);
      });
    });
    group('littleEndianToBigInt', () {
      test('Get bit integer from little endian', () {
        List<int> bytes = [10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0];
        expect(Converter.littleEndianToBigInt(Uint8List.fromList(bytes)),
            BigInt.parse('13292279960944008827972097230598307840'));
      });
    });
    group('toLittleEndian', () {
      test('reverses hexadecimal byte order', () {
        expect(Converter.toLittleEndian('12345678'), '78563412');
      });
    });
    group('binaryToBytes', () {
      test('Check bits to uint8 list', () {
        expect(
            Converter.binaryToBytes([0, 0, 1, 1]), Uint8List.fromList([0x03]));
      });
    });
    group('convertBits', () {
      test('8-bit to 5-bit conversion (Bech32 encoding)', () {
        var input = [255]; // 8-bit max value (1111 1111)
        var expectedOutput = [31, 28]; // 5-bit max value chunks
        expect(Converter.convertBits(input, 8, 5, pad: true),
            equals(expectedOutput));
      });

      test('5-bit to 8-bit conversion', () {
        var input = [31, 31, 31, 31, 31]; // 5-bit chunks
        var expectedOutput = [255, 255, 255, 128]; // 8-bit value
        expect(Converter.convertBits(input, 5, 8, pad: true),
            equals(expectedOutput));
      });

      test('Zero input case', () {
        var input = [0, 0, 0];
        var expectedOutput = [0, 0, 0, 0, 0];
        expect(Converter.convertBits(input, 8, 5, pad: true),
            equals(expectedOutput));
      });

      test('Padding enabled should add zero bits', () {
        var input = [1, 2, 3];
        var expectedOutput = [0, 4, 1, 0, 6]; // Adjusted to 5-bit chunks
        expect(Converter.convertBits(input, 8, 5, pad: true),
            equals(expectedOutput));
      });

      test('Illegal zero padding should throw FormatException', () {
        var input = [1, 2, 3];
        expect(() => Converter.convertBits(input, 8, 5, pad: false),
            throwsFormatException);
      });

      test('Negative values should throw FormatException', () {
        var input = [-1, 2, 3];
        expect(() => Converter.convertBits(input, 8, 5, pad: true),
            throwsFormatException);
      });

      test('Values out of range should throw FormatException', () {
        var input = [256]; // 8-bit max is 255
        expect(() => Converter.convertBits(input, 8, 5, pad: true),
            throwsFormatException);
      });
    });
    group("derToRawSignature", () {
      test("Get raw signature from der (case 1)", () {
        String der =
            '3044022051b558cdf6c0b2380798708ee596de9dfcffe8482cda01cd6532c6a2c34f79cd022031615f5c1b73eda34ec496f133c2e8a6cc04dd3683de1991c869fb8cbd33f18a01';
        String raw =
            '51b558cdf6c0b2380798708ee596de9dfcffe8482cda01cd6532c6a2c34f79cd31615f5c1b73eda34ec496f133c2e8a6cc04dd3683de1991c869fb8cbd33f18a';
        expect(
            Codec.encodeHex(Converter.derToRawSignature(Codec.decodeHex(der))),
            raw);
      });

      test('Rejects malformed DER signatures', () {
        final List<String> malformed = [
          '',
          '30',
          // Wrong sequence tag.
          '3144022051b558cdf6c0b2380798708ee596de9dfcffe8482cda01cd6532c6a2c34f79cd022031615f5c1b73eda34ec496f133c2e8a6cc04dd3683de1991c869fb8cbd33f18a01',
          // Wrong sequence length.
          '3043022051b558cdf6c0b2380798708ee596de9dfcffe8482cda01cd6532c6a2c34f79cd022031615f5c1b73eda34ec496f133c2e8a6cc04dd3683de1991c869fb8cbd33f18a01',
          // Negative R.
          '30440220d1b558cdf6c0b2380798708ee596de9dfcffe8482cda01cd6532c6a2c34f79cd022031615f5c1b73eda34ec496f133c2e8a6cc04dd3683de1991c869fb8cbd33f18a01',
          // Redundant leading zero in R.
          '304502210051b558cdf6c0b2380798708ee596de9dfcffe8482cda01cd6532c6a2c34f79cd022031615f5c1b73eda34ec496f133c2e8a6cc04dd3683de1991c869fb8cbd33f18a01',
        ];

        for (final String signature in malformed) {
          expect(() => Converter.derToRawSignature(Codec.decodeHex(signature)),
              throwsFormatException,
              reason: signature);
        }
      });
    });

    group("rawToDerSignature", () {
      test("Get raw signature from der (case 1)", () {
        String der =
            '3044022051b558cdf6c0b2380798708ee596de9dfcffe8482cda01cd6532c6a2c34f79cd022031615f5c1b73eda34ec496f133c2e8a6cc04dd3683de1991c869fb8cbd33f18a01';
        String raw =
            '51b558cdf6c0b2380798708ee596de9dfcffe8482cda01cd6532c6a2c34f79cd31615f5c1b73eda34ec496f133c2e8a6cc04dd3683de1991c869fb8cbd33f18a';
        expect(
            Codec.encodeHex(Converter.rawToDerSignature(Codec.decodeHex(raw))),
            der);
      });
    });
  });
}
