part of '../../coconut_lib.dart';

class RedeemScript extends Script {
  RedeemScript(super._cmds);

  factory RedeemScript.multiSignature(
      int requiredSignature, int totalSignature, List<Uint8List> publicKeys) {
    List<dynamic> cmds = [];
    cmds.add(ScriptOperationCode.getHex('OP_${requiredSignature.toString()}'));
    for (var publicKey in publicKeys) {
      cmds.add(publicKey);
    }
    cmds.add(ScriptOperationCode.getHex('OP_${totalSignature.toString()}'));
    cmds.add(ScriptOperationCode.getHex('OP_CHECKMULTISIG'));
    return RedeemScript(cmds);
  }
}
