@Tags(['unit'])
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../mock_factory.dart';

void main() {
  group('Utxo', () {
    late Utxo utxo;

    setUpAll(() async {
      utxo = MockFactory.createUtxo(entropy: 'ABC');
    });
    group('transactionHash', () {
      test('Get transaction hash', () {
        expect(utxo.transactionHash.hashCode, 1052119297);
      });
    });
    group('index', () {
      test('Get transaction index', () {
        expect(utxo.index, 0);
      });
    });
    group('amount', () {
      test('Get amount', () {
        expect(utxo.amount, 100000);
      });
    });
    group('operator ==', () {
      test('Check equal', () {
        Utxo targetUtxo = Utxo(
          utxo.transactionHash,
          utxo.index,
          utxo.amount,
          utxo.derivationPath,
        );
        expect(utxo == targetUtxo, true);
      });
    });
    group('hashCode', () {
      test('Get hash code', () {
        expect(utxo.hashCode, 277499242);
      });
    });
  });
}
