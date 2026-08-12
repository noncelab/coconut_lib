part of '../../coconut_lib.dart';

/// Encodes and decodes Bitcoin wire-format and key representations.
///
/// {@category Cryptography and Encoding}
class Codec {
  Codec._();

  static Map<String, dynamic> _decodeJsonObject(String source,
      {String name = 'JSON'}) {
    final dynamic decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('$name must be a JSON object.');
    }
    return decoded;
  }

  static T _readJsonField<T>(Map<String, dynamic> object, String field,
      {String name = 'JSON'}) {
    final dynamic value = object[field];
    if (value is! T) {
      throw FormatException('$name field "$field" must be a $T.');
    }
    return value;
  }

  /// Decodes an even-length hexadecimal string into bytes.
  static Uint8List decodeHex(String hexString) {
    if (hexString.length.isOdd) {
      throw const FormatException(
          'Hex string must contain an even number of characters.');
    }
    List<int> bytes = [];
    for (int i = 0; i < hexString.length; i += 2) {
      String byte = hexString.substring(i, i + 2);
      int decimal = int.parse(byte, radix: 16);
      bytes.add(decimal);
    }

    return Uint8List.fromList(bytes);
  }

  /// Encodes [byteList] as lowercase hexadecimal.
  static String encodeHex(List<int> byteList) {
    StringBuffer buffer = StringBuffer();
    for (int byte in byteList) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Decodes a Bitcoin CompactSize integer at [offset].
  static int decodeVariableInteger(Uint8List s, int offset) {
    if (offset < 0 || offset >= s.length) {
      throw const FormatException('CompactSize prefix is missing.');
    }
    final firstByte = s[offset];
    final int encodedLength = firstByte < 0xfd
        ? 1
        : firstByte == 0xfd
            ? 3
            : firstByte == 0xfe
                ? 5
                : 9;
    if (offset + encodedLength > s.length) {
      throw const FormatException('Truncated CompactSize value.');
    }
    if (firstByte < 0xfd) {
      return firstByte;
    } else if (firstByte == 0xfd) {
      return ByteData.sublistView(s, offset + 1, offset + 3)
          .getUint16(0, Endian.little);
    } else if (firstByte == 0xfe) {
      return ByteData.sublistView(s, offset + 1, offset + 5)
          .getUint32(0, Endian.little);
    } else {
      return ByteData.sublistView(s, offset + 1, offset + 9)
          .getUint64(0, Endian.little);
    }
  }

  /// Returns the encoded CompactSize length indicated at [offset].
  static int getVariableIntegerLength(Uint8List bytes, int offset) {
    if (offset < 0 || offset >= bytes.length) {
      throw const FormatException('CompactSize prefix is missing.');
    }
    final int prefix = bytes[offset];
    if (prefix < 0xfd) return 1;
    if (prefix == 0xfd) return 3;
    if (prefix == 0xfe) return 5;
    return 9;
  }

  /// Encodes [i] using Bitcoin CompactSize format.
  static Uint8List encodeVariableInteger(int i) {
    if (i < 0xfd) {
      return Uint8List.fromList([i.toInt()]);
    } else if (i < 0x10000) {
      return Uint8List.fromList(
          [0xfd] + Converter.intToLittleEndianBytes(i.toInt(), 2));
    } else if (i < 0x100000000) {
      return Uint8List.fromList(
          [0xfe] + Converter.intToLittleEndianBytes(i.toInt(), 4));
    } else {
      throw ArgumentError('integer too large: $i');
    }
  }

  /// Encodes raw [bytes] using the Bitcoin Base58 alphabet.
  static String encodeBase58(Uint8List bytes) {
    String alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    BigInt num = BigInt.parse(
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16);
    String base58 = '';

    while (num > BigInt.zero) {
      final BigInt mod = num % BigInt.from(58);
      base58 = alphabet[mod.toInt()] + base58;
      num ~/= BigInt.from(58);
    }

    for (final byte in bytes) {
      if (byte == 0) {
        base58 = alphabet[0] + base58;
      } else {
        break;
      }
    }

    return base58;
  }

  /// Encodes [bytes] using Base58Check with a four-byte checksum.
  static String encodeBase58Checksum(Uint8List bytes) {
    var doubleHash =
        Hash.sha256fromByte(Hash.sha256fromByte(Uint8List.fromList(bytes)));
    final Uint8List checksum = Uint8List.fromList(doubleHash.sublist(0, 4));
    final Uint8List payload = Uint8List.fromList([...bytes, ...checksum]);
    return encodeBase58(payload);
  }

  /// Decodes and verifies a Base58Check string.
  static Uint8List decodeBase58(String base58Text) {
    String alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    if (base58Text.isEmpty) {
      throw const FormatException('Base58 value is empty.');
    }
    List<int> bytes = [0];
    for (int i = 0; i < base58Text.length; i++) {
      int value = alphabet.indexOf(base58Text[i]);
      if (value < 0) {
        throw FormatException(
            'Invalid Base58 character at position $i: ${base58Text[i]}');
      }

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
    for (var k = 0; base58Text[k] == '1' && k < base58Text.length - 1; ++k) {
      bytes.add(0);
    }

    return _decodeBase58Raw(Uint8List.fromList(bytes.reversed.toList()));
  }

  static Uint8List _decodeBase58Raw(Uint8List buffer) {
    if (buffer.length < 4) {
      throw const FormatException('Base58Check value is too short.');
    }
    Uint8List payload = buffer.sublist(0, buffer.length - 4);
    Uint8List checksum = buffer.sublist(buffer.length - 4);
    Uint8List target =
        Uint8List.fromList(Hash.sha256fromByte(Hash.sha256fromByte(payload)));
    if (checksum[0] != target[0] ||
        checksum[1] != target[1] ||
        checksum[2] != target[2] ||
        checksum[3] != target[3]) {
      throw const FormatException('Invalid Base58 checksum.');
    }
    return payload;
  }

  // static WIF _decodeWifRaw(Uint8List buffer, [int? version]) {
  //   if (version != null && buffer[0] != version) {
  //     throw ArgumentError("Invalid network version");
  //   }
  //   if (buffer.length == 33) {
  //     return WIF(
  //         version: buffer[0],
  //         privateKey: buffer.sublist(1, 33),
  //         compressed: false);
  //   }
  //   if (buffer.length != 34) {
  //     throw ArgumentError("Invalid WIF length");
  //   }
  //   if (buffer[33] != 0x01) {
  //     throw ArgumentError("Invalid compression flag");
  //   }
  //   return WIF(
  //       version: buffer[0],
  //       privateKey: buffer.sublist(1, 33),
  //       compressed: true);
  // }

  static Uint8List _encodeWifRaw(
      int version, Uint8List privateKey, bool compressed) {
    if (privateKey.length != 32) {
      throw ArgumentError("Invalid privateKey length");
    }
    Uint8List result = Uint8List(compressed ? 34 : 33);
    ByteData bytes = result.buffer.asByteData();
    bytes.setUint8(0, version);
    result.setRange(1, 33, privateKey);
    if (compressed) {
      result[33] = 0x01;
    }
    return result;
  }

  // static WIF decodeWif(String string, [int? version]) {
  //   return _decodeWifRaw(Codec.decodeBase58(string), version);
  // }

  /// Encodes private-key metadata as Wallet Import Format.
  static String encodeWif(WIF wif) {
    return Codec.encodeBase58(
        _encodeWifRaw(wif.version, wif.privateKey, wif.compressed));
  }
}

/// Wallet Import Format payload before Base58Check encoding.
///
/// {@category Cryptography and Encoding}
class WIF {
  /// Network version byte.
  int version;

  /// The 32-byte private key.
  Uint8List privateKey;

  /// Whether the corresponding public key uses compressed encoding.
  bool compressed;

  /// Creates Wallet Import Format metadata.
  WIF(
      {required this.version,
      required this.privateKey,
      required this.compressed});
}
