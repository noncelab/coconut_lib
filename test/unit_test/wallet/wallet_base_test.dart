@Tags(['unit'])
library;

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('WalletBase', () {
    late SingleSignatureVault vault;
    late SingleSignatureWallet wallet;

    setUpAll(() async {
      NetworkType.setNetworkType(NetworkType.regtest);
      vault = WalletFixture.p2wpkhVault();
      wallet = SingleSignatureWallet.fromDescriptor(vault.descriptor);
    });
    group('addressType', () {
      test('Get address type from wallet base', () {
        expect(wallet.addressType, AddressType.p2wpkh);
      });
    });
    group('derivationPath', () {
      test('Get derivation path', () {
        expect(wallet.derivationPath, "m/84'/1'/0'");
      });
    });
    group('accountIndex', () {
      test('Get account index', () {
        expect(wallet.accountIndex, 0);
      });
    });
    group('descriptor', () {
      test('Get descriptor', () {
        expect(vault.descriptor.hashCode, 186870090);
      });
    });
  });
}
