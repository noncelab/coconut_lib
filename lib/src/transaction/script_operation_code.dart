part of '../../coconut_lib.dart';

class ScriptOperationCode {
  Map<String, String> opCodeHexMap = {
    'OP_0': '00',
    'OP_1': '51',
    'OP_2': '52',
    'OP_3': '53',
    'OP_4': '54',
    'OP_5': '55',
    'OP_6': '56',
    'OP_7': '57',
    'OP_8': '58',
    'OP_9': '59',
    'OP_10': '5a',
    'OP_11': '5b',
    'OP_12': '5c',
    'OP_13': '5d',
    'OP_14': '5e',
    'OP_15': '5f',
    'OP_16': '60',
    'OP_CHECKMULTISIG': 'ae',
  };

  static Uint8List getHex(String opCode) {
    String? hex = ScriptOperationCode().opCodeHexMap[opCode];
    if (hex == null) {
      throw ArgumentError('Not supporting op code');
    }
    return Converter.hexToBytes(hex);
  }
}
