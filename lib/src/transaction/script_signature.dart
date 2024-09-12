part of '../../coconut_lib.dart';

/// Represents a script signature.
class ScriptSignature extends Script {
  ScriptSignature(super.cmds);

  /// Parse the script from the given script hex.
  factory ScriptSignature.parse(String script) {
    //print("script : " + Converter.hexToBytes(script).toString());
    return ScriptSignature(Script.parse(Converter.hexToBytes(script)));
  }

  /// Create a script from the given script byte.
  factory ScriptSignature.fromScriptByte(Uint8List scriptByte) {
    return ScriptSignature(scriptByte);
  }

  /// Check if the script signature is P2WPKH.
  bool isP2wpkh() {
    return commands.length == 1 && commands[0] == 0x00;
  }

  /// Check if the script signature is P2PKH.
  bool isP2pkh() {
    return commands.length == 2 &&
        commands[0].length == 71 &&
        commands[1].length == 33;
  }

  /// Get P2PKH script signature from given signature and public key.
  static ScriptSignature p2pkh(Uint8List signature, Uint8List publicKey) {
    return ScriptSignature([signature.toList(), publicKey.toList()]);
  }

  /// Get P2WPKH script signature.
  static ScriptSignature p2wpkh() {
    List<dynamic> cmds = [0x00];
    return ScriptSignature(cmds);
  }

  /// Get empty script signature.
  static ScriptSignature empty() {
    List<dynamic> cmds = [0x00];
    return ScriptSignature(cmds);
  }

  // static ScriptSignature p2wpkhInP2sh(
  //     Uint8List signature, Uint8List publicKey) {
  //   Uint8List hash = Hash.sha160fromByte(publicKey);
  //   Script redeemScript = Script([0x76, 0xa9, hash, 0x88, 0xac]);
  //   return ScriptSignature(Hash. );
  // }
}
