part of '../../coconut_lib.dart';

/// Bitcoin Script represented as decoded operation codes and pushed data.
///
/// Parse untrusted serialized scripts through the supplied parsers so malformed
/// pushes are rejected before commands are indexed. Prefer [ScriptPublicKey],
/// [MultisignatureScript], or [Miniscript] when constructing known forms.
///
/// {@category Scripts and Policies}
class Script {
  final List<dynamic> _cmds;
  bool isCoinbase = false;

  /// Script commands.
  List<dynamic> get commands => _cmds;

  /// The length of the script.
  int get length => () {
        int length = 0;
        Uint8List raw = _rawSerialize();
        length += raw.length;

        if (raw.isEmpty || (raw.length == 1 && raw[0] == 0x00)) {
          return length;
        }
        length += Codec.encodeVariableInteger(raw.length).length;
        return length;
      }();

  /// @nodoc
  Script(this._cmds);

  /// Parse the script from the given script bytes.
  static List<dynamic> parseToCommand(Uint8List script,
      {bool isCoinbase = false}) {
    if (script.isEmpty) {
      throw FormatException('Script is empty.');
    }

    if (isCoinbase) {
      if (script.length < 2) {
        throw FormatException('Invalid coinbase script.');
      }
      Script coinbaseScript = Script(script.sublist(1));
      return coinbaseScript.commands;
    }

    int offset = 0;
    final int prefixLength = (script[0] < 0xfd)
        ? 1
        : (script[0] == 0xfd)
            ? 3
            : (script[0] == 0xfe)
                ? 5
                : 9;
    if (script.length < prefixLength) {
      throw FormatException('Invalid script length prefix.');
    }
    int length = Codec.decodeVariableInteger(script, offset);
    offset += prefixLength;
    List<dynamic> cmds = [];

    if (script.length < offset + length) {
      throw FormatException('Script is shorter than its declared length.');
    }
    final int scriptEnd = offset + length;

    int count = 0;
    while (count < length) {
      if (offset >= scriptEnd) {
        throw FormatException('Unexpected end of script.');
      }
      int currentByte = script[offset];
      offset += 1;
      count += 1;
      if (currentByte >= 1 && currentByte <= 75) {
        int n = currentByte;
        if (offset + n > scriptEnd) {
          throw FormatException('Pushdata exceeds script length.');
        }
        cmds.add(script.sublist(offset, offset + n));
        offset += n;
        count += n;
      } else if (currentByte == 76) {
        if (offset + 1 > scriptEnd) {
          throw FormatException('Missing OP_PUSHDATA1 length.');
        }
        int dataLength =
            Converter.littleEndianToInt(script.sublist(offset, offset + 1));
        offset += 1;
        if (offset + dataLength > scriptEnd) {
          throw FormatException('OP_PUSHDATA1 data exceeds script length.');
        }
        cmds.add(script.sublist(offset, offset + dataLength));
        offset += dataLength;
        count += dataLength + 1;
      } else if (currentByte == 77) {
        if (offset + 2 > scriptEnd) {
          throw FormatException('Missing OP_PUSHDATA2 length.');
        }
        int dataLength =
            Converter.littleEndianToInt(script.sublist(offset, offset + 2));
        offset += 2;
        if (offset + dataLength > scriptEnd) {
          throw FormatException('OP_PUSHDATA2 data exceeds script length.');
        }
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
    if (isCoinbase) {
      return Uint8List.fromList(_cmds as List<int>);
    }
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

  String rawSerialize() {
    return Codec.encodeHex(_rawSerialize());
  }

  /// Serialize the script.
  String serialize() {
    if (commands.isEmpty) {
      return '';
    }
    Uint8List raw = _rawSerialize();
    if (raw[0] == 0x00 && raw.length == 1) {
      //segwit
      return Codec.encodeHex(raw);
    }

    String serialized =
        Codec.encodeHex(Codec.encodeVariableInteger(raw.length)) +
            Codec.encodeHex(raw);

    return serialized;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true; // Check if they are the same instance
    }
    if (other is! Script) return false; // Ensure the object is of the same type
    return serialize() == other.serialize(); // Compare properties
  }

  @override
  int get hashCode => serialize().hashCode;
}
