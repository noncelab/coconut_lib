part of '../../coconut_lib.dart';

class Converter {
  Converter._();
  static String decToHex(int decimalValue) {
    List<String> hexDigits = [
      '0',
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      'a',
      'b',
      'c',
      'd',
      'e',
      'f'
    ];
    List<String> hexString = [];

    while (decimalValue > 0) {
      int digit = decimalValue % 16;
      hexString.insert(0, hexDigits[digit]);
      decimalValue ~/= 16;
    }

    return hexString.isEmpty ? '0' : hexString.join();
  }

  static String decToHexWithPadding(int decimalValue, int padding) {
    String hexString = decToHex(decimalValue);
    return hexString.padLeft(padding, '0');
  }

  static String bigDecToHex(BigInt decimalValue) {
    String hexString = decimalValue.toRadixString(16);
    return hexString;
  }

  static Uint8List bigIntToBytes(BigInt value, {int? byteLength}) {
    if (byteLength != null) {
      final hexStr = value.toRadixString(16).padLeft(byteLength * 2, '0');
      return Uint8List.fromList(Codec.decodeHex(hexStr));
    } else {
      return Uint8List.fromList(Codec.decodeHex(bigDecToHex(value)));
    }
  }

  static String decToBin(int decimalValue) {
    if (decimalValue == 0) {
      return '0';
    }

    List<String> binaryDigits = [];
    while (decimalValue > 0) {
      binaryDigits.insert(0, (decimalValue % 2).toString());
      decimalValue ~/= 2;
    }

    return binaryDigits.join();
  }

  static int hexToDec(String hexString) {
    return int.parse(hexString, radix: 16);
  }

  static BigInt hexToBigDec(String hexString) {
    return BigInt.parse(hexString, radix: 16);
  }

  static String hexToBin(String hexString) {
    String binary = '';
    for (int i = 0; i < hexString.length; i++) {
      String digit = hexString[i];
      int decimal = int.parse(digit, radix: 16);
      String binaryDigit = decimal.toRadixString(2).padLeft(4, '0');
      binary += binaryDigit;
    }

    return binary;
  }

  static int binToDec(String binString) {
    return int.parse(binString, radix: 2);
  }

  static int uint8ListToDec(Uint8List bytes) {
    int result = 0;
    for (int i = 0; i < bytes.length; i++) {
      result = (result << 8) | bytes[i];
    }
    return result;
  }

  static String binToHex(String binary) {
    if (binary.length % 4 != 0) {
      throw const FormatException(
          'Binary string length must be a multiple of 4.');
    }
    String hex = '';
    for (int i = 0; i < binary.length; i += 4) {
      String nibble = binary.substring(i, i + 4);
      int decimal = int.parse(nibble, radix: 2);
      String hexDigit = decimal.toRadixString(16).toUpperCase();
      hex += hexDigit;
    }
    return hex;
  }

  static Uint8List binToBytes(String binString) {
    // print(binString.length);
    List<int> bytes = [];
    for (int i = 0; i < binString.length; i += 8) {
      String byte = binString.substring(i, i + 8);
      int decimal = int.parse(byte, radix: 2);
      bytes.add(decimal);
    }

    return Uint8List.fromList(bytes);
  }

  static int bytesToDec(Uint8List byteList) {
    return int.parse(Codec.encodeHex(byteList), radix: 16);
  }

  static Uint8List intToLittleEndianBytes(int value, int length) {
    Uint8List bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = value & 0xFF;
      value = value >> 8;
    }
    return Uint8List.fromList(bytes.toList());
  }

  // static Uint8List bigIntToLittleEndianBytes(BigInt value, int length) {
  //   Uint8List bytes = Uint8List(length);

  //   // Fill the buffer with the little-endian bytes of the BigInt value
  //   for (int i = 0; i < length; i++) {
  //     bytes[i] = ((value >> (8 * i)) & BigInt.from(0xff)).toInt();
  //   }

  //   return bytes;
  // }

  static int littleEndianToInt(Uint8List bytes) {
    int result = 0;
    for (int i = 0; i < bytes.length; i++) {
      result += bytes[i] << (8 * i);
    }
    return result;
    //return ByteData.sublistView(bytes).getUint64(0, Endian.little);
  }

  static BigInt littleEndianToBigInt(Uint8List bytes) {
    return BigInt.parse(Codec.encodeHex(bytes), radix: 16);
  }

  static String toLittleEndian(String hexString) {
    List<int> bytes = Codec.decodeHex(hexString).toList();
    bytes = bytes.reversed.toList();
    return Codec.encodeHex(Uint8List.fromList(bytes));
  }

  static Uint8List binaryToBytes(List<int> binary) {
    List<int> eightBits = [];
    if (binary.length < 8) {
      for (int i = 8 - binary.length; i > 0; i--) {
        eightBits.add(0);
      }
      eightBits.addAll(binary);
    } else {
      eightBits.addAll(binary);
    }
    Uint8List bytes = Uint8List(eightBits.length ~/ 8);
    for (int i = 0; i < eightBits.length; i += 8) {
      int byte = 0;
      for (int j = 0; j < 8; j++) {
        byte = (byte << 1) | eightBits[i + j];
      }
      bytes[i ~/ 8] = byte;
    }
    return bytes;
  }

  static List<int> bytesToBinary(Uint8List bytes) {
    final bits = <int>[];
    for (final b in bytes) {
      for (int i = 7; i >= 0; i--) {
        bits.add((b >> i) & 1);
      }
    }
    return bits;
  }

  static int binaryToDecimal(List<int> binary) {
    int result = 0;
    for (int bit in binary) {
      result = (result << 1) | bit;
    }
    return result;
  }

  static List<int> convertBits(List<int> data, int from, int to,
      {bool pad = false}) {
    var acc = 0;
    var bits = 0;
    var result = <int>[];
    var maxv = (1 << to) - 1;

    for (var v in data) {
      if (v < 0 || (v >> from) != 0) {
        throw const FormatException('Input value exceeds source bit width.');
      }
      acc = (acc << from) | v;
      bits += from;
      while (bits >= to) {
        bits -= to;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (to - bits)) & maxv);
      }
    } else if (bits >= from) {
      throw const FormatException('Illegal zero padding.');
    } else if (((acc << (to - bits)) & maxv) != 0) {
      throw const FormatException('Non-zero padding.');
    }

    return result;
  }

  static Uint8List rawToDerSignature(Uint8List raw) {
    if (raw.length != 64) {
      throw ArgumentError('Raw signature must be 64 bytes');
    }

    Uint8List r = _ensureDerInt(raw.sublist(0, 32));
    Uint8List s = _ensureDerInt(raw.sublist(32, 64));

    int totalLen = 2 + r.length + 2 + s.length;
    return Uint8List.fromList(
        [0x30, totalLen, 0x02, r.length, ...r, 0x02, s.length, ...s, 0x01]);
  }

  static Uint8List derToRawSignature(Uint8List der) {
    _validateDerSignature(der);

    final int rLen = der[3];
    final Uint8List r = _normalizeRawInt(der.sublist(4, 4 + rLen));

    final int sLengthIndex = 5 + rLen;
    final int sStart = sLengthIndex + 1;
    final int sLen = der[sLengthIndex];
    final Uint8List s = _normalizeRawInt(der.sublist(sStart, sStart + sLen));

    return Uint8List.fromList([...r, ...s]);
  }

  static void _validateDerSignature(Uint8List signature) {
    // BIP66 bounds include the trailing sighash type byte.
    if (signature.length < 9 || signature.length > 73) {
      throw FormatException('Invalid DER signature length.');
    }
    if (signature[0] != 0x30) {
      throw FormatException('Invalid DER sequence tag.');
    }
    if (signature[1] != signature.length - 3) {
      throw FormatException('Invalid DER sequence length.');
    }
    if (signature[2] != 0x02) {
      throw FormatException('Invalid DER R integer tag.');
    }

    final int rLen = signature[3];
    if (rLen == 0 || 5 + rLen >= signature.length) {
      throw FormatException('Invalid DER R length.');
    }
    if ((signature[4] & 0x80) != 0) {
      throw FormatException('DER R must be positive.');
    }
    if (rLen > 1 && signature[4] == 0x00 && (signature[5] & 0x80) == 0) {
      throw FormatException('DER R is not minimally encoded.');
    }

    final int sTagIndex = 4 + rLen;
    final int sLengthIndex = sTagIndex + 1;
    if (signature[sTagIndex] != 0x02) {
      throw FormatException('Invalid DER S integer tag.');
    }

    final int sLen = signature[sLengthIndex];
    final int sStart = sLengthIndex + 1;
    final int derEnd = signature.length - 1;
    if (sLen == 0 || sStart + sLen != derEnd) {
      throw FormatException('Invalid DER S length.');
    }
    if ((signature[sStart] & 0x80) != 0) {
      throw FormatException('DER S must be positive.');
    }
    if (sLen > 1 &&
        signature[sStart] == 0x00 &&
        (signature[sStart + 1] & 0x80) == 0) {
      throw FormatException('DER S is not minimally encoded.');
    }
  }

  // static Uint8List _ensureDerInt(Uint8List raw) {
  //   if (raw[0] & 0x80 != 0) {
  //     return Uint8List.fromList([0x00, ...raw]);
  //   }
  //   return raw;
  // }

  static Uint8List _ensureDerInt(Uint8List rawInt) {
    // 앞의 불필요한 0x00 제거
    int offset = 0;
    while (offset < rawInt.length - 1 &&
        rawInt[offset] == 0x00 &&
        (rawInt[offset + 1] & 0x80) == 0) {
      offset++;
    }

    Uint8List cleaned = rawInt.sublist(offset);

    // 만약 최상위 비트가 1이면 → 양수 표현 위해 앞에 0x00 붙이기
    if (cleaned.isNotEmpty && (cleaned[0] & 0x80) != 0) {
      return Uint8List.fromList([0x00, ...cleaned]);
    } else {
      return cleaned;
    }
  }

  static Uint8List _normalizeRawInt(Uint8List derInt) {
    // remove leading 0x00 if unnecessary
    if (derInt.length == 33 && derInt[0] == 0x00) {
      derInt = derInt.sublist(1);
    }
    if (derInt.length > 32) {
      throw FormatException('Integer too long for raw signature');
    }

    Uint8List out = Uint8List(32);
    out.setRange(32 - derInt.length, 32, derInt);
    return out;
  }
}
