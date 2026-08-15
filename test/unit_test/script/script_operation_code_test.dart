@Tags(['unit'])
library;

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

void main() {
  group('ScriptOperationCode', () {
    group('getHex', () {
      test('Get hex of code', () {
        expect(ScriptOperationCode.getHex('OP_CHECKMULTISIG'), 0xae);
      });
      test('Get invald hex of code exception', () {
        expect(() => ScriptOperationCode.getHex('OP_CHECKMULTISIGGG'),
            throwsException);
      });
    });
    group('getOpCode', () {
      test('Get operation code', () {
        expect(ScriptOperationCode.getOpCode(0xae), 'OP_CHECKMULTISIG');
      });
      test('Get invalid operation code exception', () {
        expect(() => ScriptOperationCode.getOpCode(0xFF), throwsException);
      });
    });
  });
}
