@Tags(['unit'])
library;

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

void main() {
  group('NetworkType', () {
    group('toString', () {
      test('Get network type string', () {
        expect(NetworkType.mainnet.toString(), 'mainnet');
      });
    });
    group('hashCode', () {
      test('Get hash code', () {
        expect(NetworkType.mainnet.hashCode, 136947097);
      });
    });
    group('operator ==', () {
      test('Check equal', () {
        expect(NetworkType.mainnet == NetworkType.mainnet, true);
        expect(NetworkType.testnet == NetworkType.regtest, false);
      });
    });
    group('currentNetworkType', () {
      test('Get current network type', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(NetworkType.currentNetworkType == NetworkType.mainnet, true);
      });
    });
    group('values', () {
      test('Retrieve network type', () {
        expect(NetworkType.values.length == 3, true);
      });
    });
    group('setNetworkType', () {
      test('ChangeNetworkType', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(NetworkType.currentNetworkType == NetworkType.mainnet, true);

        NetworkType.setNetworkType(NetworkType.regtest);
        expect(NetworkType.currentNetworkType == NetworkType.regtest, true);
      });
    });
    group('getNetworkType', () {
      test('Get network type from text', () {
        expect(NetworkType.getNetworkType("mainnet").toString(), "mainnet");
        expect(NetworkType.getNetworkType("testnet").toString(), "testnet");
        expect(NetworkType.getNetworkType("regtest").toString(), "regtest");
        expect(() => NetworkType.getNetworkType("Holesky").toString(),
            throwsException);
      });
    });
  });
}
