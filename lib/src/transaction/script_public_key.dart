part of '../../coconut_lib.dart';

/// Represents a public key script.
class ScriptPublicKey extends Script {
  ScriptPublicKey(super.cmds);

  /// Parse the script from the given script hex.
  factory ScriptPublicKey.parse(String script) {
    return ScriptPublicKey(Script.parse(Converter.hexToBytes(script)));
  }

  /// Create a script from the given script byte.
  factory ScriptPublicKey.fromScriptByte(List<dynamic> scriptByte) {
    return ScriptPublicKey(scriptByte);
  }

  /// Generate P2WPKH script public key from given address.
  static ScriptPublicKey p2wpkh(String address) {
    var codec = Bech32Codec().decode(address);
    codec.data.removeAt(0);
    var data8Bits = Converter.convertBits(codec.data, 5, 8, pad: false);
    //print("HERE : " + Converter.bytesToHex(data8Bits));
    return ScriptPublicKey([
      0x00,
      Uint8List.fromList(data8Bits),
    ]);
  }

  /// Generate P2PKH script public key from given address.
  static ScriptPublicKey p2pkh(String address) {
    List<int> h160 = Base58.decode(address);
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
  static ScriptPublicKey p2sh(String address) {
    List<int> h160 = Base58.decode(address);
    h160 = h160.sublist(1);
    return ScriptPublicKey([
      0xa9,
      h160,
      0x87,
    ]);
  }

  String _getSegwitHrp() {
    String hrp;
    bool isTestnet = BitcoinNetwork.currentNetwork.isTestnet;
    if (!isTestnet) {
      hrp = 'bc';
    } else if (BitcoinNetwork.currentNetwork == BitcoinNetwork.testnet) {
      hrp = 'tb';
    } else {
      hrp = 'bcrt';
    }

    return hrp;
  }

  /// Get the address from the script.
  String getAddress() {
    bool isTestnet = BitcoinNetwork.currentNetwork.isTestnet;
    //todo: other address type
    if (isP2WPKH()) {
      String hrp = _getSegwitHrp();

      Uint8List h160 = commands[1];
      var data5Bits =
          Converter.convertBits(Uint8List.fromList(h160), 8, 5, pad: true);
      return bech32.encode(Bech32(hrp, [0x00] + data5Bits));
    } else if (isP2PKH()) {
      Uint8List prefix =
          isTestnet ? Uint8List.fromList([0x6f]) : Uint8List.fromList([0x00]);
      Uint8List h160 = commands[2];
      Uint8List prefixedHash = Uint8List.fromList(prefix + h160);
      return Base58.encodeChecksum(prefixedHash);
    } else if (isP2SH()) {
      Uint8List prefix =
          isTestnet ? Uint8List.fromList([0xc4]) : Uint8List.fromList([0x05]);
      Uint8List h160 = commands[1];
      Uint8List prefixedHash = Uint8List.fromList(prefix + h160);
      return Base58.encodeChecksum(prefixedHash);
    } else if (isP2TR()) {
      String hrp = _getSegwitHrp();
      Uint8List h256 = commands[1];
      var data5Bits =
          Converter.convertBits(Uint8List.fromList(h256), 8, 5, pad: true);
      bech32m.Bech32mCodec codec = bech32m.Bech32mCodec();
      return codec.encode(bech32m.Bech32m(hrp, [0x01] + data5Bits));
    } else if (isP2WSH()) {
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
  bool isP2WPKH() {
    return commands.length == 2 &&
        commands[0] == 0x00 &&
        commands[1] is Uint8List &&
        commands[1].length == 20;
  }

  /// Check if the script is P2PKH.
  bool isP2PKH() {
    return commands.length == 5 &&
        commands[0] == 0x76 &&
        commands[1] == 0xa9 &&
        commands[3] == 0x88 &&
        commands[4] == 0xac &&
        commands[2] is Uint8List &&
        commands[2].length == 20;
  }

  /// Check if the script is P2SH.
  bool isP2SH() {
    return commands.length == 3 &&
        commands[0] == 0xa9 &&
        commands[2] == 0x87 &&
        commands[1] is Uint8List &&
        commands[1].length == 20;
  }

  /// Check if the script is P2WSH.
  bool isP2WSH() {
    return commands.length == 2 &&
        commands[0] == 0x00 &&
        commands[1] is Uint8List &&
        commands[1].length == 32;
  }

  /// Check if the script is P2TR.
  bool isP2TR() {
    return commands.length == 2 &&
        commands[0] == 0x51 &&
        commands[1] is Uint8List &&
        commands[1].length == 32;
  }
}
