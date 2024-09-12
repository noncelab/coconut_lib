import 'dart:typed_data';
import 'converter.dart';

class Varints {
  static int read(Uint8List s, int offset) {
    final firstByte = s[offset];
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

  static Uint8List encode(int i) {
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
}

void main() {
  // Example integers
  String inputString =
      'd06050454abde3bdd947312b9f54439acb097608a47b0b36a23d76820a3a4044000000006a4730440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be0012102742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8dfffffffff';
  Uint8List bytes = Converter.hexToBytes(inputString);
  var scriptSize = Varints.read(bytes, 36);
  print(scriptSize);
}
