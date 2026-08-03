part of '../../coconut_lib.dart';

/// Represents a public key script.
class ScriptPublicKey extends Script {
  ScriptPublicKey(List<dynamic> cmds) : super(cmds) {
    _validateWitnessV0Commands(cmds);
  }

  /// Parse the script from the given script hex.
  factory ScriptPublicKey.parse(String script) {
    return ScriptPublicKey(Script.parseToCommand(Codec.decodeHex(script)));
  }

  /// Generate P2PKH script public key from given address.
  factory ScriptPublicKey.p2pkh(String address) {
    List<int> h160 = Codec.decodeBase58(address);
    h160 = h160.sublist(1);
    return ScriptPublicKey([
      0x76,
      0xa9,
      h160,
      0x88,
      0xac,
    ]);
  }

  /// Generate P2SH script public key from given address.
  factory ScriptPublicKey.p2sh(String address) {
    List<int> h160 = Codec.decodeBase58(address);
    h160 = h160.sublist(1);
    return ScriptPublicKey([
      0xa9,
      h160,
      0x87,
    ]);
  }

  /// Generate P2WPKH script public key from given address.
  factory ScriptPublicKey.p2wpkh(String address) {
    final Uint8List program = _decodeWitnessV0Program(address);
    if (program.length != 20) {
      throw FormatException('P2WPKH witness program must be 20 bytes.');
    }
    return ScriptPublicKey([
      0x00,
      program,
    ]);
  }

  factory ScriptPublicKey.p2wsh(String address) {
    final Uint8List program = _decodeWitnessV0Program(address);
    if (program.length != 32) {
      throw FormatException('P2WSH witness program must be 32 bytes.');
    }
    return ScriptPublicKey([
      0x00,
      program,
    ]);
  }

  factory ScriptPublicKey._fromSegwitV0Address(String address) {
    return ScriptPublicKey([0x00, _decodeWitnessV0Program(address)]);
  }

  static Uint8List _decodeWitnessV0Program(String address) {
    final Bech32 codec = Bech32Codec().decode(address);
    if (codec.data.isEmpty || codec.data.first != 0) {
      throw FormatException('Address is not witness version 0.');
    }
    final Uint8List program = Uint8List.fromList(
        Converter.convertBits(codec.data.sublist(1), 5, 8, pad: false));
    _validateWitnessV0Program(program);
    return program;
  }

  static void _validateWitnessV0Commands(List<dynamic> commands) {
    if (commands.length == 2 &&
        commands.first == 0x00 &&
        commands[1] is List<int>) {
      _validateWitnessV0Program(Uint8List.fromList(commands[1] as List<int>));
    }
  }

  static void _validateWitnessV0Program(Uint8List program) {
    if (program.length != 20 && program.length != 32) {
      throw FormatException(
          'Witness version 0 program must be 20 or 32 bytes.');
    }
  }

  factory ScriptPublicKey.p2tr(String address) {
    var codec = bech32m.Bech32mCodec().decode(address);
    codec.data.removeAt(0);
    var data8Bits = Converter.convertBits(codec.data, 5, 8, pad: false);
    if (data8Bits.length != 32) {
      throw Exception(
          "Invalid Taproot address: data8Bits length is ${data8Bits.length}, expected 32.");
    }
    return ScriptPublicKey([
      0x51,
      Uint8List.fromList(data8Bits),
    ]);
  }

  String _getSegwitHrp() {
    String hrp;
    bool isTestnet = NetworkType.currentNetworkType.isTestnet;
    if (!isTestnet) {
      hrp = 'bc';
    } else if (NetworkType.currentNetworkType == NetworkType.testnet) {
      hrp = 'tb';
    } else {
      hrp = 'bcrt';
    }

    return hrp;
  }

  /// Get the address from the script.
  String getAddress() {
    bool isTestnet = NetworkType.currentNetworkType.isTestnet;
    //todo: other address type
    if (isP2wpkh()) {
      String hrp = _getSegwitHrp();

      Uint8List h160 = commands[1];
      var data5Bits =
          Converter.convertBits(Uint8List.fromList(h160), 8, 5, pad: true);
      return bech32.encode(Bech32(hrp, [0x00] + data5Bits));
    } else if (isP2pkh()) {
      Uint8List prefix =
          isTestnet ? Uint8List.fromList([0x6f]) : Uint8List.fromList([0x00]);
      Uint8List h160 = commands[2];
      Uint8List prefixedHash = Uint8List.fromList(prefix + h160);
      return Codec.encodeBase58Checksum(prefixedHash);
    } else if (isP2sh()) {
      Uint8List prefix =
          isTestnet ? Uint8List.fromList([0xc4]) : Uint8List.fromList([0x05]);
      Uint8List h160 = commands[1];
      Uint8List prefixedHash = Uint8List.fromList(prefix + h160);
      return Codec.encodeBase58Checksum(prefixedHash);
    } else if (isP2tr()) {
      String hrp = _getSegwitHrp();
      Uint8List h256 = commands[1];
      var data5Bits =
          Converter.convertBits(Uint8List.fromList(h256), 8, 5, pad: true);
      bech32m.Bech32mCodec codec = bech32m.Bech32mCodec();
      return codec.encode(bech32m.Bech32m(hrp, [0x01] + data5Bits));
    } else if (isP2wsh()) {
      String hrp = _getSegwitHrp();
      Uint8List h256 = commands[1];
      var data5Bits =
          Converter.convertBits(Uint8List.fromList(h256), 8, 5, pad: true);
      return bech32.encode(Bech32(hrp, [0x00] + data5Bits));
    } else {
      return 'Script : Non-standard script.';
    }
  }

  /// Check if the script is P2WPKH.
  bool isP2wpkh() {
    return commands.length == 2 &&
        commands[0] == 0x00 &&
        commands[1] is Uint8List &&
        commands[1].length == 20;
  }

  /// Check if the script is P2PKH.
  bool isP2pkh() {
    return commands.length == 5 &&
        commands[0] == 0x76 &&
        commands[1] == 0xa9 &&
        commands[3] == 0x88 &&
        commands[4] == 0xac &&
        commands[2] is Uint8List &&
        commands[2].length == 20;
  }

  /// Check if the script is P2SH.
  bool isP2sh() {
    return commands.length == 3 &&
        commands[0] == 0xa9 &&
        commands[2] == 0x87 &&
        commands[1] is Uint8List &&
        commands[1].length == 20;
  }

  /// Check if the script is P2WSH.
  bool isP2wsh() {
    return commands.length == 2 &&
        commands[0] == 0x00 &&
        commands[1] is Uint8List &&
        commands[1].length == 32;
  }

  /// Check if the script is P2TR.
  bool isP2tr() {
    return commands.length == 2 &&
        commands[0] == 0x51 &&
        commands[1] is Uint8List &&
        commands[1].length == 32;
  }
}
