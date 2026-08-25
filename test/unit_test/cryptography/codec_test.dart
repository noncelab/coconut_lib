import 'dart:typed_data';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

void main() {
  group('Codec', () {
    group('encodeHex', () {
      test('Get hexadecimal from bytes', () {
        List<int> bytes = [173];
        expect(Codec.encodeHex(bytes), 'ad');
      });
    });
    group('decodeHex', () {
      test('Get bytes from hexadecimal', () {
        String hexString = 'ad';
        expect(Codec.decodeHex(hexString), [173]);
      });
      test('Reject odd-length hexadecimal', () {
        expect(() => Codec.decodeHex('abc'), throwsFormatException);
      });
    });
    group('decodeVariableInteger', () {
      test('1-byte integer (0x00 ~ 0xfc)', () {
        for (int i = 0; i <= 0xfc; i++) {
          Uint8List input = Uint8List.fromList([i]);
          expect(Codec.decodeVariableInteger(input, 0), equals(i));
        }
      });

      test('2-byte integer (0xfd prefix)', () {
        Uint8List input =
            Uint8List.fromList([0xfd, 0x34, 0x12]); // 0x1234 (4660)
        expect(Codec.decodeVariableInteger(input, 0), equals(0x1234));
      });

      test('4-byte integer (0xfe prefix)', () {
        Uint8List input =
            Uint8List.fromList([0xfe, 0x78, 0x56, 0x34, 0x12]); // 0x12345678
        expect(Codec.decodeVariableInteger(input, 0), equals(0x12345678));
      });

      test('8-byte integer (0xff prefix)', () {
        Uint8List input = Uint8List.fromList([
          0xff,
          0xef,
          0xcd,
          0xab,
          0x89,
          0x67,
          0x45,
          0x23,
          0x01
        ]); // 0x0123456789abcdef
        expect(
            Codec.decodeVariableInteger(input, 0), equals(0x0123456789abcdef));
      });

      test('Invalid input: too short for 2-byte integer', () {
        Uint8List input = Uint8List.fromList([0xfd]);
        expect(
            () => Codec.decodeVariableInteger(input, 0), throwsFormatException);
      });

      test('Invalid input: too short for 4-byte integer', () {
        Uint8List input = Uint8List.fromList([0xfe, 0x12, 0x34]);
        expect(
            () => Codec.decodeVariableInteger(input, 0), throwsFormatException);
      });

      test('Invalid input: too short for 8-byte integer', () {
        Uint8List input = Uint8List.fromList([0xff, 0x12, 0x34, 0x56]);
        expect(
            () => Codec.decodeVariableInteger(input, 0), throwsFormatException);
      });
    });
    group('getVariableIntegerLength', () {
      test('returns the encoded length from the prefix at an offset', () {
        final input =
            Uint8List.fromList([0x00, 0xfc, 0xfd, 0x00, 0x00, 0xfe, 0xff]);

        expect(Codec.getVariableIntegerLength(input, 0), 1);
        expect(Codec.getVariableIntegerLength(input, 1), 1);
        expect(Codec.getVariableIntegerLength(input, 2), 3);
        expect(Codec.getVariableIntegerLength(input, 5), 5);
        expect(Codec.getVariableIntegerLength(input, 6), 9);
      });

      test('throws when the offset is outside the input', () {
        expect(() => Codec.getVariableIntegerLength(Uint8List(0), 0),
            throwsFormatException);
      });
    });
    group('encodeVariableInteger', () {
      test('1-byte integer (0x00 ~ 0xfc)', () {
        for (int i = 0x00; i <= 0xfc; i++) {
          Uint8List encoded = Codec.encodeVariableInteger(i);
          expect(encoded, equals(Uint8List.fromList([i])));
        }
      });

      test('2-byte integer (0xfd prefix)', () {
        Uint8List encoded = Codec.encodeVariableInteger(0x1234);
        expect(encoded,
            equals(Uint8List.fromList([0xfd, 0x34, 0x12]))); // Little Endian
      });

      test('4-byte integer (0xfe prefix)', () {
        Uint8List encoded = Codec.encodeVariableInteger(0x12345678);
        expect(
            encoded,
            equals(Uint8List.fromList(
                [0xfe, 0x78, 0x56, 0x34, 0x12]))); // Little Endian
      });

      test('Invalid: Too large integer (should throw ArgumentError)', () {
        expect(() => Codec.encodeVariableInteger(0x100000000),
            throwsArgumentError);
      });

      test('Boundary check: 0xfc (should be 1 byte)', () {
        Uint8List encoded = Codec.encodeVariableInteger(0xfc);
        expect(encoded, equals(Uint8List.fromList([0xfc])));
      });

      test('Boundary check: 0xfd (should be 3 bytes with prefix)', () {
        Uint8List encoded = Codec.encodeVariableInteger(0xfd);
        expect(encoded,
            equals(Uint8List.fromList([0xfd, 0xfd, 0x00]))); // 0xfd00 in LE
      });

      test('Boundary check: 0xffff (should be 3 bytes with prefix)', () {
        Uint8List encoded = Codec.encodeVariableInteger(0xffff);
        expect(encoded,
            equals(Uint8List.fromList([0xfd, 0xff, 0xff]))); // 0xffff in LE
      });

      test('Boundary check: 0x10000 (should be 5 bytes with prefix)', () {
        Uint8List encoded = Codec.encodeVariableInteger(0x10000);
        expect(
            encoded,
            equals(Uint8List.fromList(
                [0xfe, 0x00, 0x00, 0x01, 0x00]))); // 0x00010000 in LE
      });

      test('Boundary check: 0xffffffff (should be 5 bytes with prefix)', () {
        Uint8List encoded = Codec.encodeVariableInteger(0xffffffff);
        expect(
            encoded,
            equals(Uint8List.fromList(
                [0xfe, 0xff, 0xff, 0xff, 0xff]))); // 0xffffffff in LE
      });
    });
    group('encodeBase58', () {
      test('Basic encoding: 0x01', () {
        Uint8List input = Uint8List.fromList([0x01]);
        expect(Codec.encodeBase58(input), equals('2'));
      });

      test('Encoding zero bytes should add leading 1s', () {
        Uint8List input = Uint8List.fromList([0x00, 0x00, 0x01]);
        expect(Codec.encodeBase58(input), equals('112'));
      });

      test('Known Base58 encoded value', () {
        Uint8List input = Uint8List.fromList([
          0x80,
          0x4B,
          0xF1,
          0xF9,
          0x1F,
          0xAE,
          0x5D,
          0x6A,
          0x79,
          0x3E,
          0x1C,
          0xFA,
          0x12,
          0xBD,
          0x57,
          0x48,
          0xA3,
          0xBE,
          0x19,
          0x0A,
          0x54,
          0xE0,
          0x2C,
          0x3D,
          0x97,
          0x67,
          0x11,
          0x05,
          0x16,
          0x5B,
          0xE3,
          0xC0,
          0xC4,
          0x73,
          0x98
        ]);
        expect(Codec.encodeBase58(input),
            equals('DoV1ZPRVymfZEk9Q1Q2uLanHu1kWDaTKvgBdAn9BV66sHqSo'));
      });

      test('Longer input encoding', () {
        Uint8List input = Uint8List.fromList(List.generate(32, (i) => i + 1));
        expect(Codec.encodeBase58(input), isNotEmpty);
      });

      test('Zero byte only input', () {
        Uint8List input = Uint8List.fromList([0x00]);
        expect(Codec.encodeBase58(input), equals('1'));
      });

      test('Multiple zero bytes input', () {
        Uint8List input = Uint8List.fromList([0x00, 0x00, 0x00]);
        expect(Codec.encodeBase58(input), equals('111'));
      });

      test('Known example with leading zeros', () {
        Uint8List input = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
        expect(Codec.encodeBase58(input), equals('1Ldp'));
      });
    });

    group('encodeBase58Checksum', () {
      test('Basic encoding with checksum', () {
        Uint8List input = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
        String base58WithChecksum = Codec.encodeBase58Checksum(input);
        expect(base58WithChecksum, isNotEmpty);
      });

      test('Known Base58Check encoding', () {
        Uint8List input = Uint8List.fromList([
          0x80,
          0x4B,
          0xF1,
          0xF9,
          0x1F,
          0xAE,
          0x5D,
          0x6A,
          0x79,
          0x3E,
          0x1C,
          0xFA,
          0x12,
          0xBD,
          0x57,
          0x48,
          0xA3,
          0xBE,
          0x19,
          0x0A,
          0x54,
          0xE0,
          0x2C,
          0x3D,
          0x97,
          0x67,
          0x11,
          0x05,
          0x16,
          0x5B,
          0xE3,
          0xC0,
          0xC4,
          0x73,
          0x98
        ]);
        String expectedOutput =
            "2SmYhS3RJDFmnPDMeBBpAStoNwAMXskVmmQKytcEpRf7veL79Q5CgH";
        expect(Codec.encodeBase58Checksum(input), equals(expectedOutput));
      });

      test('Checksum should be 4 bytes', () {
        Uint8List input = Uint8List.fromList([0x01, 0x02, 0x03]);
        var doubleHash =
            Hash.sha256fromByte(Hash.sha256fromByte(Uint8List.fromList(input)));
        final Uint8List checksum = Uint8List.fromList(doubleHash.sublist(0, 4));

        expect(checksum.length, equals(4));
      });

      test('Checksum should change if input changes', () {
        Uint8List input1 = Uint8List.fromList([0x01, 0x02, 0x03]);
        Uint8List input2 = Uint8List.fromList([0x01, 0x02, 0x04]);
        expect(Codec.encodeBase58Checksum(input1),
            isNot(equals(Codec.encodeBase58Checksum(input2))));
      });

      test('Empty input should return valid Base58Check', () {
        Uint8List input = Uint8List(0);
        String result = Codec.encodeBase58Checksum(input);
        expect(result, isNotEmpty);
      });
    });

    group('decodeBase58', () {
      test('Get decoded from base58', () {
        String input = "2N2JD6wb56AfK4tfmM6PwdVmoYk2dCKf4Br";
        expect(Codec.decodeBase58(input), [
          196,
          99,
          73,
          164,
          24,
          252,
          69,
          120,
          209,
          10,
          55,
          43,
          84,
          180,
          92,
          40,
          12,
          200,
          196,
          56,
          47
        ]);
      });

      test('Empty input should throw an exception', () {
        expect(() => Codec.decodeBase58(""), throwsFormatException);
      });

      test('Invalid Base58 characters should throw an exception', () {
        expect(() => Codec.decodeBase58("O0I!"),
            throwsFormatException); // 'O', '0', 'I' are invalid in Base58
      });
    });

    group('encodeWif', () {
      test('Get wif', () {
        WIF wif = WIF(
            version: 128,
            privateKey: Uint8List.fromList([
              106,
              140,
              71,
              57,
              116,
              255,
              171,
              191,
              43,
              172,
              54,
              173,
              173,
              211,
              40,
              186,
              171,
              248,
              182,
              215,
              162,
              105,
              182,
              155,
              184,
              8,
              216,
              13,
              100,
              241,
              127,
              65
            ]),
            compressed: true);
        expect(Codec.encodeWif(wif),
            '3uNnGw4JgsA7hujrSBWqqXCWYQigfK22MSbeoHg6zniQP9J');
      });
    });
  });
}
