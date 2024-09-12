part of '../../coconut_lib.dart';

/// Represents a script in a transaction.
class Script {
  final List<dynamic> _cmds;

  /// Script commands.
  List<dynamic> get commands => _cmds;

  /// The length of the script.
  int get length => () {
        int length = 0;
        Uint8List raw = _rawSerialize();
        length += raw.length;

        if (raw[0] == 0x00 && raw.length == 1) {
          return length;
        }
        length += Varints.encode(raw.length).length;
        return length;
      }();

  /// @nodoc
  Script(this._cmds);

  /// Parse the script from the given script bytes.
  static List<dynamic> parse(Uint8List script) {
    int offset = 0;
    int length = Varints.read(script, offset);
    offset += (length < 0xfd)
        ? 1
        : (length == 0xfd)
            ? 3
            : (length == 0xfe)
                ? 5
                : 9;
    List<dynamic> cmds = [];

    int count = 0;
    while (count < length) {
      int currentByte = script[offset];
      offset += 1;
      count += 1;
      if (currentByte >= 1 && currentByte <= 75) {
        int n = currentByte;
        cmds.add(script.sublist(offset, offset + n));
        offset += n;
        count += n;
      } else if (currentByte == 76) {
        int dataLength =
            Converter.littleEndianToInt(script.sublist(offset, offset + 1));
        offset += 1;
        cmds.add(script.sublist(offset, offset + dataLength));
        offset += dataLength;
        count += dataLength + 1;
      } else if (currentByte == 77) {
        int dataLength =
            Converter.littleEndianToInt(script.sublist(offset, offset + 2));
        offset += 2;
        cmds.add(script.sublist(offset, offset + dataLength));
        offset += dataLength;
        count += dataLength + 2;
      } else {
        int opCode = currentByte;
        cmds.add(opCode);
      }
    }
    if (count != length) {
      throw FormatException('parsing script failed');
    }
    return cmds;
  }

  Uint8List _rawSerialize() {
    List<int> serialized = [];
    for (var cmd in commands) {
      if (cmd is int) {
        serialized.add(cmd);
      } else {
        Uint8List data = Uint8List.fromList(cmd);
        if (data.length < 76) {
          serialized.add(data.length);
        } else if (data.length < 0x100) {
          serialized.add(76);
          serialized.addAll(Converter.intToLittleEndianBytes(data.length, 1));
        } else if (data.length < 0x10000) {
          serialized.add(77);
          serialized.addAll(Converter.intToLittleEndianBytes(data.length, 2));
        }
        serialized.addAll(data);
      }
    }
    return Uint8List.fromList(serialized);
  }

  /// Serialize the script.
  String serialize() {
    if (commands.isEmpty) {
      return '';
    }
    Uint8List raw = _rawSerialize();
    if (raw[0] == 0x00 && raw.length == 1) {
      //segwit
      return Converter.bytesToHex(raw);
    }

    return Converter.bytesToHex(Varints.encode(raw.length)) +
        Converter.bytesToHex(raw);
  }
}
