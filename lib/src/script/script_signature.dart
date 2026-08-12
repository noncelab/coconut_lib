part of '../../coconut_lib.dart';

/// Represents a script signature.
///
/// {@category Scripts and Policies}
class ScriptSignature extends Script {
  ScriptSignature(super.cmds);

  /// Parse the script from the given script hex.
  factory ScriptSignature.parse(String script) {
    //print("script : " + Converter.hexToBytes(script).toString());
    return ScriptSignature(Script.parseToCommand(Codec.decodeHex(script)));
  }

  factory ScriptSignature.forCoinbase(String script) {
    ScriptSignature scriptSignature = ScriptSignature(
        Script.parseToCommand(Codec.decodeHex(script), isCoinbase: true));
    scriptSignature.isCoinbase = true;
    return scriptSignature;
  }

  /// Get P2PKH script signature from given signature and public key.
  factory ScriptSignature.p2pkh(Uint8List signature, Uint8List publicKey) {
    return ScriptSignature([signature.toList(), publicKey.toList()]);
  }

  /// Get P2WPKH script signature.
  factory ScriptSignature.p2wpkh() {
    return ScriptSignature.empty();
  }

  /// Get P2WSH script signature.
  factory ScriptSignature.p2wsh() {
    return ScriptSignature.empty();
  }

  /// Get empty script signature.
  factory ScriptSignature.empty() {
    List<dynamic> cmds = [0x00];
    return ScriptSignature(cmds);
  }
}
