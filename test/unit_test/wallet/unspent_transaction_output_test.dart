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

    group('constructor', () {
      const String transactionHash =
          '0000000000000000000000000000000000000000000000000000000000000000';
      const String derivationPath = "m/84'/1'/0'/0/0";

      test('accepts valid boundary values', () {
        expect(Utxo(transactionHash, 0, 0, derivationPath).index, 0);

        final Utxo maximum = Utxo(transactionHash, Utxo.maxOutputIndex,
            Utxo.maxMoney, derivationPath);
        expect(maximum.index, Utxo.maxOutputIndex);
        expect(maximum.amount, Utxo.maxMoney);
      });

      test('rejects a transaction hash that is not 32-byte hex', () {
        for (final String invalidHash in [
          '',
          '00' * 31,
          '00' * 33,
          'gg' * 32,
        ]) {
          expect(() => Utxo(invalidHash, 0, 0, derivationPath),
              throwsFormatException,
              reason: invalidHash);
        }
      });

      test('rejects an index outside the uint32 range', () {
        expect(() => Utxo(transactionHash, -1, 0, derivationPath),
            throwsRangeError);
        expect(
            () => Utxo(
                transactionHash, Utxo.maxOutputIndex + 1, 0, derivationPath),
            throwsRangeError);
      });

      test('rejects an amount outside the Bitcoin money range', () {
        expect(() => Utxo(transactionHash, 0, -1, derivationPath),
            throwsRangeError);
        expect(
            () => Utxo(transactionHash, 0, Utxo.maxMoney + 1, derivationPath),
            throwsRangeError);
      });
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
