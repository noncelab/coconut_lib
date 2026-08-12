@Tags(['unit'])
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('ExtendedPublicKey', () {
    late ExtendedPublicKey extendedPublicKey;

    setUp(() {
      NetworkType.setNetworkType(NetworkType.testnet);
      extendedPublicKey =
          WalletFixture.p2wpkhVault().keyStore.extendedPublicKey;
    });

    group('depth', () {
      test('returns the derivation depth', () {
        expect(extendedPublicKey.depth, 3);
      });
    });
    group('parentFingerprintByte', () {
      test('returns the parent fingerprint bytes', () {
        expect(Codec.encodeHex(extendedPublicKey.parentFingerprintByte),
            extendedPublicKey.parentFingerprint);
      });
    });
    group('parentFingerprint', () {
      test('returns the hexadecimal parent fingerprint', () {
        expect(extendedPublicKey.parentFingerprint, hasLength(8));
      });
    });
    group('index', () {
      test('returns the hardened account index', () {
        expect(extendedPublicKey.index, 0x80000000);
      });
    });
    group('chainCode', () {
      test('returns a 32-byte chain code', () {
        expect(extendedPublicKey.chainCode, hasLength(32));
      });
    });
    group('publicKey', () {
      test('returns a compressed public key', () {
        expect(extendedPublicKey.publicKey, hasLength(33));
      });
    });
    group('version', () {
      test('returns the configured extended-key version', () {
        expect(extendedPublicKey.version, AddressType.p2wpkh.versionForTestnet);
      });
    });
    group('fromHdWallet', () {
      test('Generate ExtendedPublicKey', () {
        SingleSignatureVault vault = WalletFixture.p2wpkhVault();
        HDWallet hdWallet = vault.keyStore.hdWallet;
        ExtendedPublicKey extendedPublicKey = ExtendedPublicKey.fromHdWallet(
            hdWallet,
            AddressType.p2wpkh.versionForTestnet,
            Uint8List.fromList(hdWallet.parentFingerprint));

        expect(extendedPublicKey.serialize(),
            vault.keyStore.extendedPublicKey.serialize());
      });
    });
    group('fromPublicKey', () {
      test('Generate ExtendedPublicKey from public key', () {
        String publicKey =
            '021A3BF5FBF737D0F36993FD46DC4913093BEB532D654FE0DFD98BD27585DC9F29';
        String chainCode =
            'BBA0C7CA160A870EFEB940AB90D0F4284FEA1B5E0D2117677E823FC37E2D5763';
        String pfp = '1cf29716';
        int version = AddressType.p2wsh.versionForMainnet;
        String derivationPath =
            WalletUtility.getDerivationPath(AddressType.p2wsh, 0);
        ExtendedPublicKey extendedPublicKey = ExtendedPublicKey.fromPublicKey(
            Codec.decodeHex(publicKey),
            Codec.decodeHex(chainCode),
            version,
            Codec.decodeHex(pfp),
            derivationPath);
        expect(extendedPublicKey.serialize(),
            'Zpub74Jru6aftwwHxCUCWEvP6DgrfFsdA4U6ZRtQ5i8qJpMcC39yZGv3egBhQfV3MS9pZtH5z8iV5qWkJsK6ESs6mSzt4qvGhzJxPeeVS2e1zUG');
      });
    });
    group('parse', () {
      test('Parse extended public key', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        String exPubText =
            'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs';
        ExtendedPublicKey extendedPublicKey =
            ExtendedPublicKey.parse(exPubText);

        expect(extendedPublicKey.parentFingerprint, '7ef32bdb');
      });
      test('Parse extended public key (network type mismatch)', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        String exPubText =
            'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs';

        expect(() => ExtendedPublicKey.parse(exPubText), throwsException);
      });

      test('can skip network validation', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        const String exPubText =
            'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs';

        final ExtendedPublicKey parsed =
            ExtendedPublicKey.parse(exPubText, validateNetwork: false);

        expect(parsed.parentFingerprint, '7ef32bdb');
      });
    });
    group('serialize', () {
      test('Serialise extended public key', () {
        SingleSignatureVault vault = WalletFixture.p2wpkhVault();
        expect(vault.keyStore.extendedPublicKey.serialize(),
            'vpub5ZZ1q76vi2LR9PeQDoV13u8TZwsyqKa7yBfD3GnPPvBjVU9ZnBTMkwzCHCVBZaPHDKJNEdMKo8MTyrQ9234idzSG9nHFD6hsUB8HJ14NBg7');
      });

      test('Serialise extended public key to xpub', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        SingleSignatureVault vault = WalletFixture.p2wpkhVault();
        expect(vault.keyStore.extendedPublicKey.serialize(toXpub: true),
            'xpub6CGPh2qh56Rq6cq3jeemUUuSRcha3GrVrs9QMLkikfu253nziERNLqabWB49qyqkVvHJ1iB9M3CCxkHNLv2xrSNhhbxHTku6Ld22Az4cMG6');
      });
    });
    group('serializeForPsbt', () {
      test('serializes the 78-byte payload without Base58Check encoding', () {
        final serialized = extendedPublicKey.serializeForPsbt();
        expect(serialized, hasLength(156));
        expect(Codec.decodeHex(serialized), hasLength(78));
      });
    });

    group('toString', () {
      test('returns the serialized extended public key', () {
        expect(extendedPublicKey.toString(), extendedPublicKey.serialize());
      });
    });

    group('operator ==', () {
      test('compares serialized extended public keys', () {
        expect(ExtendedPublicKey.parse(extendedPublicKey.serialize()),
            extendedPublicKey);
      });
    });

    group('hashCode', () {
      test('Get hash code', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        SingleSignatureVault vault = WalletFixture.p2wpkhVault();
        HDWallet hdWallet = vault.keyStore.hdWallet;
        ExtendedPublicKey extendedPublicKey = ExtendedPublicKey.fromHdWallet(
            hdWallet,
            AddressType.p2wpkh.versionForTestnet,
            Uint8List.fromList(hdWallet.parentFingerprint));

        expect(extendedPublicKey.hashCode,
            vault.keyStore.extendedPublicKey.hashCode);
      });
    });
  });
}
