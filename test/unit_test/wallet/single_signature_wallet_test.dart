@Tags(['unit'])
library;

import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() async {
  group('SingleSignatureWallet', () {
    late SingleSignatureVault vault;
    late SingleSignatureWallet wallet;

    setUpAll(() async {
      NetworkType.setNetworkType(NetworkType.regtest);
      vault = WalletFixture.p2wpkhVault();
      wallet = SingleSignatureWallet.fromDescriptor(vault.descriptor);
    });
    group('SingleSignatureWallet', () {
      test('stores only a neutered copy of a private HD wallet', () {
        final keyStore =
            KeyStore.fromSeed(SeedFixture.common(), AddressType.p2wpkh);
        final target = SingleSignatureWallet(
            keyStore.masterFingerprint,
            keyStore.hdWallet,
            AddressType.p2wpkh,
            WalletUtility.getDerivationPath(AddressType.p2wpkh, 0),
            keyStore.extendedPublicKey);

        expect(keyStore.hdWallet.isNeutered(), isFalse);
        expect(target.keyStore.hdWallet.isNeutered(), isTrue);
        expect(target.keyStore.hasSeed, isFalse);
        expect(target.keyStore.hdWallet.privateKey, isNull);
      });

      test('rejects a key from another network', () {
        NetworkType.setNetworkType(NetworkType.testnet);
        final keyStore =
            KeyStore.fromSeed(SeedFixture.common(), AddressType.p2wpkh);
        NetworkType.setNetworkType(NetworkType.mainnet);
        try {
          expect(
              () => SingleSignatureWallet(
                  keyStore.masterFingerprint,
                  keyStore.hdWallet,
                  AddressType.p2wpkh,
                  "m/84'/0'/0'",
                  keyStore.extendedPublicKey),
              throwsException);
        } finally {
          NetworkType.setNetworkType(NetworkType.regtest);
        }
      });

      test('rejects malformed derivation paths', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        final keyStore =
            KeyStore.fromSeed(SeedFixture.common(), AddressType.p2wpkh);
        try {
          expect(
              () => SingleSignatureWallet(
                  keyStore.masterFingerprint,
                  keyStore.hdWallet,
                  AddressType.p2wpkh,
                  'invalid',
                  keyStore.extendedPublicKey),
              throwsException);
        } finally {
          NetworkType.setNetworkType(NetworkType.regtest);
        }
      });

      test('rejects a derivation path for another network', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        final keyStore =
            KeyStore.fromSeed(SeedFixture.common(), AddressType.p2wpkh);
        try {
          expect(
              () => SingleSignatureWallet(
                  keyStore.masterFingerprint,
                  keyStore.hdWallet,
                  AddressType.p2wpkh,
                  "m/84'/1'/0'",
                  keyStore.extendedPublicKey),
              throwsException);
        } finally {
          NetworkType.setNetworkType(NetworkType.regtest);
        }
      });
    });
    group('SingleSignatureWallet.fromDescriptor', () {
      test('Generate single signature wallet from descriptor', () {
        SingleSignatureWallet targetWallet =
            SingleSignatureWallet.fromDescriptor(vault.descriptor);
        expect(targetWallet.derivationPath, vault.derivationPath);
        expect(targetWallet.addressType, vault.addressType);
        expect(targetWallet.keyStore.masterFingerprint,
            vault.keyStore.masterFingerprint);
      });
      test('Generate single signature wallet from multisignature exception',
          () {
        expect(
            () => SingleSignatureWallet.fromDescriptor(
                WalletFixture.p2wshVault().descriptor),
            throwsException);
      });

      test('Invalid derivation path (testnet)', () {
        String descriptor =
            "wpkh([98C7D774/84'/0'/0']vpub5ZZ1q76vi2LR9PeQDoV13u8TZwsyqKa7yBfD3GnPPvBjVU9ZnBTMkwzCHCVBZaPHDKJNEdMKo8MTyrQ9234idzSG9nHFD6hsUB8HJ14NBg7/<0;1>/*)#7ra9g9d8";
        NetworkType.setNetworkType(NetworkType.testnet);
        expect(
            () => SingleSignatureWallet.fromDescriptor(descriptor,
                ignoreChecksum: true),
            throwsException);
      });

      test('Invalid derivation path (mainnet)', () {
        String descriptor =
            "wpkh([98C7D774/84'/1'/0']vpub5ZZ1q76vi2LR9PeQDoV13u8TZwsyqKa7yBfD3GnPPvBjVU9ZnBTMkwzCHCVBZaPHDKJNEdMKo8MTyrQ9234idzSG9nHFD6hsUB8HJ14NBg7/<0;1>/*)#7ra9g9d8";
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(
            () => SingleSignatureWallet.fromDescriptor(descriptor,
                ignoreChecksum: true),
            throwsException);
      });
    });
    group('toJson', () {
      test('Get json text of single signature wallet', () {
        expect(wallet.toJson().hashCode, 275252338);
      });
    });
    group('SingleSignatureWallet.fromJson', () {
      test('Generate single signature wallet from json', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        SingleSignatureWallet targetWallet =
            SingleSignatureWallet.fromJson(wallet.toJson());
        expect(targetWallet.keyStore.masterFingerprint,
            wallet.keyStore.masterFingerprint);
      });
    });
    group('SingleSignatureWallet.fromCryptoAccountPayload', () {
      final String payload = '''
        {
          "1": 3461324038,
          "2": [
            {
              "2": false,
              "3": [2, 197, 249, 234, 124, 34, 59, 192, 56, 207, 250, 215, 89, 251, 76, 223, 178, 197, 191, 188, 23, 63, 255, 90, 81, 231, 146, 114, 144, 168, 93, 35, 98],
              "4": [68, 222, 40, 247, 168, 57, 78, 216, 188, 75, 124, 217, 32, 75, 208, 85, 105, 231, 96, 160, 199, 204, 117, 157, 171, 123, 123, 111, 26, 45, 209, 9],
              "5": {
                "1": 0,
                "2": 0
              },
              "6": {
                "1": [
                  84,
                  true,
                  0,
                  true,
                  0,
                  true
                ],
                "2": 3461324038,
                "3": 3
              },
              "7": {
                "1": [
                  0,
                  false,
                  [],
                  false
                ],
                "3": 0
              },
              "8": 2319540438
            },
            {
              "2": false,
              "3": [3, 155, 238, 178, 30, 71, 89, 113, 67, 117, 220, 124, 30, 247, 83, 198, 76, 105, 153, 184, 41, 98, 220, 133, 53, 69, 177, 241, 171, 107, 236, 82, 182],
              "4": [255, 219, 143, 163, 11, 242, 199, 87, 135, 73, 113, 186, 98, 11, 63, 237, 7, 137, 143, 230, 90, 88, 27, 111, 21, 114, 131, 187, 17, 94, 10, 32],
              "5": {
                "1": 0,
                "2": 0
              },
              "6": {
                "1": [
                  49,
                  true,
                  0,
                  true,
                  0,
                  true
                ],
                "2": 3461324038,
                "3": 3
              },
              "7": {
                "1": [
                  0,
                  false,
                  [],
                  false
                ],
                "3": 0
              },
              "8": 117992223
            },
            {
              "2": false,
              "3": [3, 172, 27, 116, 8, 181, 179, 14, 203, 179, 35, 254, 163, 39, 19, 213, 236, 44, 73, 70, 124, 201, 93, 155, 179, 99, 220, 94, 173, 43, 74, 219, 255],
              "4": [206, 215, 150, 204, 241, 52, 255, 211, 102, 127, 216, 47, 241, 51, 123, 29, 14, 101, 154, 144, 159, 193, 198, 49, 244, 37, 255, 82, 9, 199, 149, 140],
              "5": {
                "1": 0,
                "2": 0
              },
              "6": {
                "1": [
                  44,
                  true,
                  0,
                  true,
                  0,
                  true
                ],
                "2": 3461324038,
                "3": 3
              },
              "7": {
                "1": [
                  0,
                  false,
                  [],
                  false
                ],
                "3": 0
              },
              "8": 2486618859
            }
          ]
        }
        ''';
      final String payload2 = '''
          {"1":953202145,"2":[
          {"2":false,"3":${Codec.decodeHex("033558A7656D16D946497D8B458AEB84CFCEB4F2D471D7FF5A9E4FA4488412DF63")},"4":${Codec.decodeHex("23936EF00D3B0C27674C3EE47CFE8A5032AB161B3A1F851CF39977DFE06DD756")},"5":{"1":0,"2":0},"6":{"1":[84,true,1,true,0,true],"2":953202145,"3":3},"7":{"1":[0,false,[],false],"3":0},"8":3254928504}]
          }
          ''';
      test(
          'Generate single signature wallet from crypto account payload (case 1)',
          () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        SingleSignatureWallet wallet =
            SingleSignatureWallet.fromCryptoAccountPayload(jsonDecode(payload));

        expect(
            Codec.encodeHex(wallet.keyStore.extendedPublicKey.publicKey)
                .toUpperCase(),
            '02C5F9EA7C223BC038CFFAD759FB4CDFB2C5BFBC173FFF5A51E7927290A85D2362');
        expect(wallet.keyStore.extendedPublicKey.parentFingerprint,
            Converter.decToHex(2319540438));
        expect(
            wallet.keyStore.masterFingerprint, Converter.decToHex(3461324038));
        expect(wallet.derivationPath, "m/84'/0'/0'");
        expect(wallet.addressType, AddressType.p2wpkh);
      });

      test(
          'Generate single signature wallet from crypto account payload (case 2)',
          () {
        NetworkType.setNetworkType(NetworkType.testnet);
        SingleSignatureWallet wallet =
            SingleSignatureWallet.fromCryptoAccountPayload(
                jsonDecode(payload2));

        expect(
            Codec.encodeHex(wallet.keyStore.extendedPublicKey.publicKey)
                .toUpperCase(),
            '033558A7656D16D946497D8B458AEB84CFCEB4F2D471D7FF5A9E4FA4488412DF63');
        expect(wallet.keyStore.extendedPublicKey.parentFingerprint,
            Converter.decToHex(3254928504));
        expect(
            wallet.keyStore.masterFingerprint, Converter.decToHex(953202145));
        expect(wallet.derivationPath, "m/84'/1'/0'");
        expect(wallet.addressType, AddressType.p2wpkh);
      });

      test('Network type is not match with payload', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        expect(
            () => SingleSignatureWallet.fromCryptoAccountPayload(
                jsonDecode(payload)),
            throwsException);
      });
    });

    group('SingleSignatureWallet.fromExtendedPublicKey', () {
      test('Generate single signature wallet from extended public key', () {
        NetworkType.setNetworkType(NetworkType.testnet);
        String extendedPublicKey =
            'vpub5ZQx1972mMdbKZuuscy9QMJEeokWQNPoYr8dbW4QkVa4ZAK54vSSqFsGYTPJMUWxVpnF6VGvGde27bECuMkB7HWE8FUSQ4sSptAfbEg7zmF';
        SingleSignatureWallet wallet =
            SingleSignatureWallet.fromExtendedPublicKey(
                AddressType.p2wpkh, extendedPublicKey, '499602d2');
        expect(wallet.keyStore.extendedPublicKey.parentFingerprint,
            Converter.decToHex(3254928504));
        expect(wallet.keyStore.masterFingerprint, '499602d2');
        expect(wallet.derivationPath, "m/84'/1'/0'");
        expect(wallet.addressType, AddressType.p2wpkh);
      });
    });
  });
}
