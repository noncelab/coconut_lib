import 'dart:typed_data';
import 'package:coconut_lib/src/utils/hash.dart';

class Base58 {
  static final String _alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static String encode(Uint8List bytes) {
    BigInt num = BigInt.parse(
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16);
    String base58 = '';

    while (num > BigInt.zero) {
      final BigInt mod = num % BigInt.from(58);
      base58 = _alphabet[mod.toInt()] + base58;
      num ~/= BigInt.from(58);
    }

    for (final byte in bytes) {
      if (byte == 0) {
        base58 = _alphabet[0] + base58;
      } else {
        break;
      }
    }

    return base58;
  }

  static String encodeChecksum(Uint8List bytes) {
    var doubleHash =
        Hash.sha256fromByte(Hash.sha256fromByte(Uint8List.fromList(bytes)));
    final Uint8List checksum = Uint8List.fromList(doubleHash.sublist(0, 4));
    final Uint8List payload = Uint8List.fromList([...bytes, ...checksum]);
    return encode(payload);
  }

  static Uint8List decode(String string) {
    if (string.isEmpty) {
      throw Exception('Base58 : Not Base58 string');
    }
    List<int> bytes = [0];
    for (int i = 0; i < string.length; i++) {
      int value = _alphabet.indexOf(string[i]);

      var carry = value;
      for (var j = 0; j < bytes.length; ++j) {
        carry += bytes[j] * 58;
        bytes[j] = carry & 0xff;
        carry >>= 8;
      }
      while (carry > 0) {
        bytes.add(carry & 0xff);
        carry >>= 8;
      }
    }
    // deal with leading zeros
    for (var k = 0; string[k] == '1' && k < string.length - 1; ++k) {
      bytes.add(0);
    }

    return decodeRaw(Uint8List.fromList(bytes.reversed.toList()));
  }

  static Uint8List decodeRaw(Uint8List buffer) {
    Uint8List payload = buffer.sublist(0, buffer.length - 4);
    Uint8List checksum = buffer.sublist(buffer.length - 4);
    Uint8List target =
        Uint8List.fromList(Hash.sha256fromByte(Hash.sha256fromByte(payload)));
    if (checksum[0] != target[0] ||
        checksum[1] != target[1] ||
        checksum[2] != target[2] ||
        checksum[3] != target[3]) {
      throw Exception("Base58 : Invalid checksum");
    }
    return payload;
  }
}
