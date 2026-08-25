import 'dart:convert';
import 'dart:typed_data';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

void main() {
  group('Hash', () {
    group('sha256', () {
      test('Get sha256', () {
        final result = Hash.sha256('test');
        expect(Codec.encodeHex(result),
            '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08');
      });
    });
    group('sha256fromHex', () {
      test('Get sha256 from hex', () {
        final result = Hash.sha256fromHex('74657374');
        expect(result,
            '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08');
      });
    });
    group('sha256fromByte', () {
      test('Get sha256 from byte', () {
        final result =
            Hash.sha256fromByte(Uint8List.fromList([116, 101, 115, 116]));
        expect(
            result,
            Uint8List.fromList([
              159,
              134,
              208,
              129,
              136,
              76,
              125,
              101,
              154,
              47,
              234,
              160,
              197,
              90,
              208,
              21,
              163,
              191,
              79,
              27,
              43,
              11,
              130,
              44,
              209,
              93,
              108,
              21,
              176,
              240,
              10,
              8
            ]));
      });
    });
    group('hmacSha512', () {
      test('Get hmac sha 512', () {
        Uint8List key = Uint8List.fromList([
          76,
          250,
          197,
          156,
          175,
          155,
          225,
          66,
          132,
          16,
          41,
          22,
          151,
          23,
          123,
          46,
          252,
          131,
          115,
          162,
          159,
          122,
          212,
          163,
          70,
          148,
          22,
          54,
          134,
          164,
          210,
          11
        ]);
        Uint8List data = Uint8List.fromList([
          3,
          248,
          248,
          161,
          65,
          43,
          158,
          86,
          221,
          149,
          118,
          244,
          154,
          224,
          166,
          73,
          151,
          87,
          234,
          89,
          43,
          212,
          145,
          249,
          16,
          200,
          245,
          25,
          239,
          14,
          167,
          207,
          60,
          0,
          0,
          0,
          1
        ]);
        Uint8List hmacsha512 = Uint8List.fromList([
          38,
          33,
          244,
          107,
          233,
          236,
          83,
          136,
          156,
          68,
          247,
          171,
          53,
          32,
          130,
          227,
          16,
          82,
          152,
          44,
          107,
          245,
          27,
          124,
          11,
          232,
          208,
          96,
          163,
          50,
          152,
          4,
          159,
          128,
          190,
          219,
          136,
          10,
          13,
          28,
          26,
          11,
          127,
          94,
          103,
          13,
          239,
          71,
          108,
          213,
          129,
          135,
          254,
          196,
          20,
          123,
          89,
          189,
          204,
          56,
          73,
          104,
          46,
          55
        ]);
        expect(Hash.hmacSha512(key, data), hmacsha512);
      });
    });
    group('sha160fromHex', () {
      test('Get sha160 from hex', () {
        final result = Hash.sha160fromHex('74657374');
        expect(
            result,
            Uint8List.fromList([
              206,
              186,
              169,
              140,
              25,
              128,
              113,
              52,
              67,
              77,
              16,
              123,
              13,
              62,
              86,
              146,
              165,
              22,
              234,
              102
            ]));
      });
    });
    group('sha160fromByte', () {
      test('Get sha160 from byte', () {
        final result =
            Hash.sha160fromByte(Uint8List.fromList([116, 101, 115, 116]));
        expect(
            result,
            Uint8List.fromList([
              206,
              186,
              169,
              140,
              25,
              128,
              113,
              52,
              67,
              77,
              16,
              123,
              13,
              62,
              86,
              146,
              165,
              22,
              234,
              102
            ]));
      });
    });
    group('pbkdf2', () {
      test('Get pbkdf2', () {
        final result =
            Hash.pbkdf2(utf8.encode('password'), utf8.encode('salt'));
        expect(
            result,
            Codec.decodeHex(
                '91be23564f09fc855c82ce84a223ebe7d63d8b49d69372593a0d9ed39e143c83e1ab2f722a5ddb969feefc88403f7e2afe1afb8b2f0e6b20add0fb7b28368807'));
      });
    });
    group('taggedHash', () {
      test('Get tagged hash', () {
        final result = Hash.taggedHash('tag', Hash.sha256('salt'));
        expect(Codec.encodeHex(result),
            '8a38cdedb7e8e90315ef4d169732c89e7dbfe24e28a7467d43841c5e74c04aec');
      });
    });
    group('hashTapTweak', () {
      test('hashes the public key when merkle root is absent', () {
        final publicKey = Uint8List.fromList(List<int>.generate(32, (i) => i));
        expect(Hash.hashTapTweak('TapTweak', publicKey, null),
            Hash.taggedHash('TapTweak', publicKey));
      });

      test('includes the merkle root when present', () {
        final publicKey = Uint8List.fromList(List<int>.filled(32, 1));
        final merkleRoot = Uint8List.fromList(List<int>.filled(32, 2));
        expect(Hash.hashTapTweak('TapTweak', publicKey, merkleRoot),
            Hash.taggedHash('TapTweak', publicKey + merkleRoot));
      });
    });
  });
}
