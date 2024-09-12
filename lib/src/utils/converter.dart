import 'dart:typed_data';

class Converter {
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

  static String binToHex(String binary) {
    if (binary.length % 4 != 0) {
      throw Exception('Invalid binary string(not multiple of 4)');
    }
    String hex = '';
    for (int i = 0; i < binary.length; i += 4) {
      String nibble = binary.substring(i, i + 4);
      int decimal = int.parse(nibble, radix: 2);
      String hexDigit = decimal.toRadixString(16).toUpperCase();
      hex += hexDigit;
    }
    // int decimalValue = int.parse(binString, radix: 2);

    // String hexString = decimalValue.toRadixString(16).toUpperCase();

    // int length = binString.length ~/ 4;
    // String paddedHexString = hexString.padLeft(length, '0');

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

  static String bytesToBin(List<int> bytes) {
    String binary = '';
    for (int byte in bytes) {
      String byteString = byte.toRadixString(2).padLeft(8, '0');
      binary += byteString;
    }

    return binary;
  }

  static String bytesToHex(List<int> byteList) {
    StringBuffer buffer = StringBuffer();
    for (int byte in byteList) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static int bytesToDec(Uint8List byteList) {
    return int.parse(bytesToHex(byteList), radix: 16);
  }

  static Uint8List hexToBytes(String hexString) {
    List<int> bytes = [];
    for (int i = 0; i < hexString.length; i += 2) {
      String byte = hexString.substring(i, i + 2);
      int decimal = int.parse(byte, radix: 16);
      bytes.add(decimal);
    }

    return Uint8List.fromList(bytes);
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
    return BigInt.parse(bytesToHex(bytes), radix: 16);
  }

  static String toLittleEndian(String hexString) {
    List<int> bytes = hexToBytes(hexString).toList();
    bytes = bytes.reversed.toList();
    return bytesToHex(Uint8List.fromList(bytes));
  }

  static List<int> convertBits(List<int> data, int from, int to,
      {bool pad = false}) {
    var acc = 0;
    var bits = 0;
    var result = <int>[];
    var maxv = (1 << to) - 1;

    for (var v in data) {
      if (v < 0 || (v >> from) != 0) {
        throw Exception();
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
      throw Exception('illegal zero padding');
    } else if (((acc << (to - bits)) & maxv) != 0) {
      throw Exception('non zero');
    }

    return result;
  }
}
