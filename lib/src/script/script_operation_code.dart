part of '../../coconut_lib.dart';

/// Lookup utilities for Bitcoin Script operation codes.
class ScriptOperationCode {
  Map<String, int> opCodeHexMap = {
    'OP_0': 0x00,
    'OP_1': 0x51,
    'OP_2': 0x52,
    'OP_3': 0x53,
    'OP_4': 0x54,
    'OP_5': 0x55,
    'OP_6': 0x56,
    'OP_7': 0x57,
    'OP_8': 0x58,
    'OP_9': 0x59,
    'OP_10': 0x5a,
    'OP_11': 0x5b,
    'OP_12': 0x5c,
    'OP_13': 0x5d,
    'OP_14': 0x5e,
    'OP_15': 0x5f,
    'OP_16': 0x60,
    'OP_CHECKMULTISIG': 0xae,
    'OP_CHECKLOCKTIMEVERIFY': 0xb1,
    'OP_CHECKSEQUENCEVERIFY': 0xb2,
    'OP_DROP': 0x75,
    'OP_CHECKSIG': 0xac,
    'OP_CHECKSIGVERIFY': 0xad,
    'OP_CHECKSIGADD': 0xba,
    'OP_NUMEQUAL': 0x87,
  };

  static int getHex(String opCode) {
    int? hex = ScriptOperationCode().opCodeHexMap[opCode];
    if (hex == null) {
      throw Exception('Not supporting op code');
    }
    return hex;
  }

  static String getOpCode(int hex) {
    for (var entry in ScriptOperationCode().opCodeHexMap.entries) {
      if (entry.value == hex) {
        return entry.key;
      }
    }
    throw Exception('Not supporting op code');
  }
}
