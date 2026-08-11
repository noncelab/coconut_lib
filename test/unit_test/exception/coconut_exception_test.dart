@Tags(['unit'])

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

void main() {
  group('CoconutException', () {
    test('exposes stable code, message, cause, and immutable context', () {
      final cause = FormatException('bad payload');
      final exception = TransactionException(
          CoconutErrorCode.insufficientFunds, 'Not enough funds',
          cause: cause, context: const {'required': 10, 'available': 5});

      expect(exception, isA<Exception>());
      expect(exception.code, CoconutErrorCode.insufficientFunds);
      expect(exception.message, 'Not enough funds');
      expect(exception.cause, same(cause));
      expect(exception.context, {'required': 10, 'available': 5});
      expect(() => exception.context['required'] = 1, throwsUnsupportedError);
      expect(exception.toString(), contains('insufficientFunds'));
    });

    test('PSBT exception includes an optional input index in context', () {
      final exception = PsbtException(
          CoconutErrorCode.policyMismatch, 'Input policy does not match',
          inputIndex: 2, context: const {'field': 'witnessScript'});

      expect(exception.inputIndex, 2);
      expect(exception.context, {'inputIndex': 2, 'field': 'witnessScript'});
    });

    test('provides domain-specific exception types', () {
      expect(
          WalletException(CoconutErrorCode.networkMismatch, 'Network mismatch'),
          isA<CoconutException>());
      expect(
          SigningException(
              CoconutErrorCode.privateKeyUnavailable, 'Missing private key'),
          isA<CoconutException>());
    });
  });
}
