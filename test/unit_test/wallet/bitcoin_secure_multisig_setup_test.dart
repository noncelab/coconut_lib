@Tags(['unit'])
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('BSMS', () {
    group('BSMS.fromSigner', () {
      test('Generate signer', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        KeyStore keyStore = KeyStore.fromSeed(Seed.random(), AddressType.p2wsh);
        Bsms bsms = Bsms.fromSigner(
            keyStore.masterFingerprint,
            (WalletUtility.getDerivationPath(AddressType.p2wsh, 0))
                .replaceAll("m/", ""),
            keyStore.extendedPublicKey.serialize(),
            'Description');
        expect(bsms.signer, isA<Signer>());
      });
    });

    group('BSMS.fromCoordinator', () {
      test('Generate coordinator', () {
        MultisignatureVault mockWallet = WalletFixture.p2wshVault();
        Bsms bsms = Bsms.fromCoordinator(
            mockWallet.getAddress(0), mockWallet.descriptor);
        expect(bsms.coordinator, isA<Coordinator>());
      });

      test('Reject mismatched first address', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        final wallet = WalletFixture.p2wshVault();
        final otherWallet = MultisignatureVault.fromSeedList([
          SeedFixture.common(passphrase: 'D'),
          SeedFixture.common(passphrase: 'E'),
        ], 1);

        expect(
            () => Bsms.fromCoordinator(
                otherWallet.getAddress(0), wallet.descriptor),
            throwsFormatException);
        NetworkType.setNetworkType(NetworkType.mainnet);
      });

      test('Reject mismatched Taproot first address', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        final wallet = WalletFixture.p2trPolicyVault();
        final otherWallet =
            WalletFixture.p2trKeyPathVault(passphrase: 'different');

        expect(
            () => Bsms.fromCoordinator(
                otherWallet.getAddress(0), wallet.descriptor),
            throwsFormatException);
        NetworkType.setNetworkType(NetworkType.mainnet);
      });
    });

    group('BSMS.parseSigner', () {
      test('Generate signer from parsing', () {
        String signer =
            "BSMS 1.0\n00\n[62A936C3/48'/0'/0'/2']Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES\noutside signer";
        expect(Bsms.parseSigner(signer), isA<Bsms>());
      });
      test('Generate signer from parsing with no description', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        String signer =
            "BSMS 1.0\n00\n[62A936C3/48'/0'/0'/2']Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES";
        Bsms bsms = Bsms.parseSigner(signer);
        expect(bsms.secretToken, '00');
        expect(bsms.signer?.masterFingerPrint, '62A936C3');
        expect(bsms.signer?.path, '48\'/0\'/0\'/2\'');
        expect(bsms.signer?.extendedPublicKey.serialize(),
            'Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES');
        expect(bsms.signer?.description, '');
      });

      test('Insufficient data exception', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        String signer = "BSMS 1.0\n00\n";
        expect(() => Bsms.parseSigner(signer), throwsException);
      });

      test('Unsupported version exception', () {
        String signer =
            "BSMS 1.1\n00\n[62A936C3/48'/0'/0'/2']Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES\noutside signer";
        expect(() => Bsms.parseSigner(signer), throwsException);
      });

      test('Unsupported secret token exception', () {
        String signer =
            "BSMS 1.0\n01\n[62A936C3/48'/0'/0'/2']Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES\noutside signer";
        expect(() => Bsms.parseSigner(signer), throwsException);
      });

      test('Invalid key info format', () {
        String signer =
            "BSMS 1.0\n00\n[62A936C3/m/48'/0'/0'/2']Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES\noutside signer";
        expect(() => Bsms.parseSigner(signer), throwsException);
      });
    });

    group('BSMS.parseCoordinator', () {
      test('Generate coordinator from parsing', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        String coordinator =
            "BSMS 1.0\nwsh(sortedmulti(2,[AEF5B293/48'/0'/0'/2']Zpub75AQJSQLp25LUmJX2fUUMJjP4fcQhwaqH32iSNckTrZrjy3omBpb1ghSNtSZpCzvzhLha7r3JA7uG4wQyDkn87qHgpPZfTHBdvghvVhL2t1/<0;1>/*,[BAD41B33/48'/0'/0'/2']Zpub74NK7csp5wpD3dmr6bwweenNKDSERwQfisZCL8JpZ2TQ64E4oHm8pesNzTytfhfpfp6XzwumdxSKgLSjogTG6r6zVd1mSgGz67zK3Me9qrQ/<0;1>/*,[62A936C3/48'/0'/0'/2']Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES/<0;1>/*))#3zwl8rzh\n/0/*,/1/*\nbc1qq4t09zkp4f422qrcqmg0xx79h5n9ujtql5rcvwc0kykwfv3rwxgqkss9ct";
        expect(Bsms.parseCoordinator(coordinator), isA<Bsms>());
      });

      test('Invalid address exception', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        String coordinator =
            "BSMS 1.0\nwsh(sortedmulti(2,[AEF5B293/48'/0'/0'/2']Zpub75AQJSQLp25LUmJX2fUUMJjP4fcQhwaqH32iSNckTrZrjy3omBpb1ghSNtSZpCzvzhLha7r3JA7uG4wQyDkn87qHgpPZfTHBdvghvVhL2t1/<0;1>/*,[BAD41B33/48'/0'/0'/2']Zpub74NK7csp5wpD3dmr6bwweenNKDSERwQfisZCL8JpZ2TQ64E4oHm8pesNzTytfhfpfp6XzwumdxSKgLSjogTG6r6zVd1mSgGz67zK3Me9qrQ/<0;1>/*,[62A936C3/48'/0'/0'/2']Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES/<0;1>/*))#3zwl8rzh\n/0/*,/1/*\nbcrt1qp2fgzezkfvnvngv0nfe5pyf2vrsrvcpa3kcac5";
        expect(() => Bsms.parseCoordinator(coordinator), throwsException);
      });

      test('First address mismatch exception', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        final wallet = WalletFixture.p2wshVault();
        final otherWallet = MultisignatureVault.fromSeedList([
          SeedFixture.common(passphrase: 'D'),
          SeedFixture.common(passphrase: 'E'),
        ], 1);
        final coordinator = wallet
            .getCoordinatorBsms()
            .replaceFirst(wallet.getAddress(0), otherWallet.getAddress(0));

        expect(() => Bsms.parseCoordinator(coordinator), throwsFormatException);
        NetworkType.setNetworkType(NetworkType.mainnet);
      });

      test('Network mismatch exception', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        final coordinator = WalletFixture.p2wshVault().getCoordinatorBsms();
        NetworkType.setNetworkType(NetworkType.mainnet);

        expect(() => Bsms.parseCoordinator(coordinator), throwsFormatException);
      });

      test('Unsupported version exception', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        String coordinator =
            "BSMS 1.1\nwsh(sortedmulti(2,[AEF5B293/48'/0'/0'/2']Zpub75AQJSQLp25LUmJX2fUUMJjP4fcQhwaqH32iSNckTrZrjy3omBpb1ghSNtSZpCzvzhLha7r3JA7uG4wQyDkn87qHgpPZfTHBdvghvVhL2t1/<0;1>/*,[BAD41B33/48'/0'/0'/2']Zpub74NK7csp5wpD3dmr6bwweenNKDSERwQfisZCL8JpZ2TQ64E4oHm8pesNzTytfhfpfp6XzwumdxSKgLSjogTG6r6zVd1mSgGz67zK3Me9qrQ/<0;1>/*,[62A936C3/48'/0'/0'/2']Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES/<0;1>/*))#3zwl8rzh\n/0/*,/1/*\nbc1qq4t09zkp4f422qrcqmg0xx79h5n9ujtql5rcvwc0kykwfv3rwxgqkss9ct";
        expect(() => Bsms.parseCoordinator(coordinator), throwsException);
      });

      test('Customized derivation path exception', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        String coordinator =
            "BSMS 1.0\nwsh(sortedmulti(2,[AEF5B293/48'/0'/0'/2']Zpub75AQJSQLp25LUmJX2fUUMJjP4fcQhwaqH32iSNckTrZrjy3omBpb1ghSNtSZpCzvzhLha7r3JA7uG4wQyDkn87qHgpPZfTHBdvghvVhL2t1/<0;1>/*,[BAD41B33/48'/0'/0'/2']Zpub74NK7csp5wpD3dmr6bwweenNKDSERwQfisZCL8JpZ2TQ64E4oHm8pesNzTytfhfpfp6XzwumdxSKgLSjogTG6r6zVd1mSgGz67zK3Me9qrQ/<0;1>/*,[62A936C3/48'/0'/0'/2']Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES/<0;1>/*))#3zwl8rzh\n/1/*,/2/*\nbc1qq4t09zkp4f422qrcqmg0xx79h5n9ujtql5rcvwc0kykwfv3rwxgqkss9ct";
        expect(() => Bsms.parseCoordinator(coordinator), throwsException);
      });
    });

    group('serializeSigner', () {
      test('Serialize signer', () {
        String signer =
            "BSMS 1.0\n00\n[62A936C3/48'/0'/0'/2']Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES\noutside signer";
        Bsms bsms = Bsms.parseSigner(signer);
        expect(bsms.serializeSigner(), signer);
      });

      test('Empty signer exception', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        String coordinator =
            "BSMS 1.0\nwsh(sortedmulti(2,[AEF5B293/48'/0'/0'/2']Zpub75AQJSQLp25LUmJX2fUUMJjP4fcQhwaqH32iSNckTrZrjy3omBpb1ghSNtSZpCzvzhLha7r3JA7uG4wQyDkn87qHgpPZfTHBdvghvVhL2t1/<0;1>/*,[BAD41B33/48'/0'/0'/2']Zpub74NK7csp5wpD3dmr6bwweenNKDSERwQfisZCL8JpZ2TQ64E4oHm8pesNzTytfhfpfp6XzwumdxSKgLSjogTG6r6zVd1mSgGz67zK3Me9qrQ/<0;1>/*,[62A936C3/48'/0'/0'/2']Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES/<0;1>/*))#3zwl8rzh\n/0/*,/1/*\nbc1qq4t09zkp4f422qrcqmg0xx79h5n9ujtql5rcvwc0kykwfv3rwxgqkss9ct";
        Bsms bsms = Bsms.parseCoordinator(coordinator);
        expect(() => bsms.serializeSigner(), throwsException);
      });
    });

    group('serializeCoordinator', () {
      test('Serialize coordiantor', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        String coordiantor =
            "BSMS 1.0\nwsh(sortedmulti(2,[AEF5B293/48'/0'/0'/2']Zpub75AQJSQLp25LUmJX2fUUMJjP4fcQhwaqH32iSNckTrZrjy3omBpb1ghSNtSZpCzvzhLha7r3JA7uG4wQyDkn87qHgpPZfTHBdvghvVhL2t1/<0;1>/*,[BAD41B33/48'/0'/0'/2']Zpub74NK7csp5wpD3dmr6bwweenNKDSERwQfisZCL8JpZ2TQ64E4oHm8pesNzTytfhfpfp6XzwumdxSKgLSjogTG6r6zVd1mSgGz67zK3Me9qrQ/<0;1>/*,[62A936C3/48'/0'/0'/2']Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES/<0;1>/*))#3zwl8rzh\n/0/*,/1/*\nbc1qq4t09zkp4f422qrcqmg0xx79h5n9ujtql5rcvwc0kykwfv3rwxgqkss9ct";
        Bsms bsms = Bsms.parseCoordinator(coordiantor);
        expect(bsms.serializeCoordinator(), coordiantor);
      });

      test('Empty coordinator exception', () {
        String signer =
            "BSMS 1.0\n00\n[62A936C3/48'/0'/0'/2']Zpub75QytCyD9mNTr1wyi59JAhU2uiPedspk18djeteoeC6tJ7MdpuKbBRUA33CW49y5FDkpPqLDjujDVaNAGB9XVw44q8X2Hzif5DSTQyhgTES\noutside signer";
        Bsms bsms = Bsms.parseSigner(signer);
        expect(() => bsms.serializeCoordinator(), throwsException);
      });
    });
  });
}
