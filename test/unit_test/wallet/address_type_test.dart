@Tags(['unit'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

void main() {
  group('AddressType', () {
    group('values', () {
      test('contains every supported address type', () {
        expect(
            AddressType.values,
            containsAll([
              AddressType.p2pkh,
              AddressType.p2wpkh,
              AddressType.p2wpkhInP2sh,
              AddressType.p2sh,
              AddressType.p2wsh,
              AddressType.p2tr,
            ]));
      });
    });
    group('isSegwit', () {
      test('identifies native SegWit address types', () {
        expect(AddressType.p2wpkh.isSegwit, isTrue);
        expect(AddressType.p2tr.isSegwit, isTrue);
        expect(AddressType.p2pkh.isSegwit, isFalse);
      });
    });
    group('isMultisignature', () {
      test('identifies multisignature address types', () {
        expect(AddressType.p2sh.isMultisignature, isTrue);
        expect(AddressType.p2wsh.isMultisignature, isTrue);
        expect(AddressType.p2wpkh.isMultisignature, isFalse);
      });
    });
    group('isSingleSignature', () {
      test('identifies single-signature address types', () {
        expect(AddressType.p2pkh.isSingleSignature, isTrue);
        expect(AddressType.p2wpkh.isSingleSignature, isTrue);
        expect(AddressType.p2wsh.isSingleSignature, isFalse);
      });
    });
    group('isTaproot', () {
      test('identifies taproot address types', () {
        expect(AddressType.p2tr.isTaproot, isTrue);
        expect(AddressType.p2wpkh.isTaproot, isFalse);
      });
    });
    group('getAddressTypeFromScriptType', () {
      test('getAddressTypeFromScriptType', () {
        expect(
            AddressType.getAddressTypeFromScriptType('pkh'), AddressType.p2pkh);
        expect(
            AddressType.getAddressTypeFromScriptType('sh'), AddressType.p2sh);
        expect(AddressType.getAddressTypeFromScriptType('wpkh'),
            AddressType.p2wpkh);
        expect(
            AddressType.getAddressTypeFromScriptType('wsh'), AddressType.p2wsh);
      });

      test('throws for unsupported script types', () {
        expect(() => AddressType.getAddressTypeFromScriptType('unknown'),
            throwsException);
      });
    });

    group('getAddressTypeFromName', () {
      test('returns the matching named address type', () {
        expect(AddressType.getAddressTypeFromName('p2tr'), AddressType.p2tr);
        expect(
            AddressType.getAddressTypeFromName('p2wpkh'), AddressType.p2wpkh);
      });

      test('throws for unsupported names', () {
        expect(() => AddressType.getAddressTypeFromName('unknown'),
            throwsException);
      });
    });

    group('isTestnetVersion', () {
      test('isTestnetVersion', () {
        expect(AddressType.isTestnetVersion(0x045f1cf6), true);
        expect(AddressType.isTestnetVersion(0x04b24746), false);
        expect(AddressType.isTestnetVersion(0x02575483), true);
        expect(AddressType.isTestnetVersion(0x02aa7ed3), false);
        expect(() => AddressType.isTestnetVersion(0x00), throwsException);
      });
    });
    group('getAddressTypeByVersion', () {
      test('getAddressTypeByVersion', () {
        expect(AddressType.getAddressTypeByVersion(0x045f1cf6),
            AddressType.p2wpkh);
        expect(AddressType.getAddressTypeByVersion(0x04b24746),
            AddressType.p2wpkh);
        expect(
            AddressType.getAddressTypeByVersion(0x02575483), AddressType.p2wsh);
        expect(
            AddressType.getAddressTypeByVersion(0x02aa7ed3), AddressType.p2wsh);
        expect(
            () => AddressType.getAddressTypeByVersion(0x00), throwsException);
      });
    });

    group('getAddress', () {
      test('getP2pkhAddress', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(
            AddressType.p2pkh.getAddress(
                '038b5e44fc67861d87842e756b8249072a55a81b0daa0bd5d14919aa75c58e9daf'),
            '1HcmPiFd9zwYzPbmv3hcEhCajHcqgdLhSK');
        NetworkType.setNetworkType(NetworkType.testnet);
        expect(
            AddressType.p2pkh.getAddress(
                '038b5e44fc67861d87842e756b8249072a55a81b0daa0bd5d14919aa75c58e9daf'),
            'mx8igmLby2NomW5Pdcfz4cQubHDYcmVmrA');
      });
      test('getP2wpkhAddress', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(
            AddressType.p2wpkh.getAddress(
                '0298029ebbc7640beb3a3e8885759d5a47e3f22d632ca58bb2815e6fcf72e0df07'),
            'bc1qxv635h49ewh5qagssy3xl8gpnr45d5hdqmd0aj');
        NetworkType.setNetworkType(NetworkType.testnet);
        expect(
            AddressType.p2wpkh.getAddress(
                '0298029ebbc7640beb3a3e8885759d5a47e3f22d632ca58bb2815e6fcf72e0df07'),
            'tb1qxv635h49ewh5qagssy3xl8gpnr45d5hd2akuxp');
      });
      test('getP2wpkhInP2shAddress', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(
            AddressType.p2wpkhInP2sh.getAddress(
                '039b3b694b8fc5b5e07fb069c783cac754f5d38c3e08bed1960e31fdb1dda35c24'),
            '37VucYSaXLCAsxYyAPfbSi9eh4iEcbShgf');
      });
      test('getWrondAddress', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(
            () => AddressType.p2wsh.getAddress(
                '039b3b694b8fc5b5e07fb069c783cac754f5d38c3e08bed1960e31fdb1dda35c24'),
            throwsException);
      });

      // Test vectors from BIP0086 (https://github.com/bitcoin/bips/blob/master/bip-0086.mediawiki#user-content-Test_vectors)
      test('getP2trTaprootAddress (case 1)', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        TaprootVault vault = TaprootVault.fromKeyStoreList([
          KeyStore.fromMnemonic(
              utf8.encode(
                  "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"),
              AddressType.p2tr)
        ], []);

        expect(
            AddressType.p2tr.getTaprootAddress(vault.keyStoreList[0]
                .getPublicKey(0, applyTweak: true, isXOnly: true)),
            'bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr');
      });
      test('getP2trKeyPathSpendingAddress (case 2)', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        TaprootVault vault = TaprootVault.fromKeyStoreList([
          KeyStore.fromMnemonic(
              utf8.encode(
                  "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"),
              AddressType.p2tr)
        ], []);

        expect(
            AddressType.p2tr.getTaprootAddress(vault.keyStoreList[0]
                .getPublicKey(1, applyTweak: true, isXOnly: true)),
            'bc1p4qhjn9zdvkux4e44uhx8tc55attvtyu358kutcqkudyccelu0was9fqzwh');
      });
      test('getP2trKeyPathSpendingAddress (case 3)', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        TaprootVault vault = TaprootVault.fromKeyStoreList([
          KeyStore.fromMnemonic(
              utf8.encode(
                  "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"),
              AddressType.p2tr)
        ], []);

        expect(
            AddressType.p2tr.getTaprootAddress(vault.keyStoreList[0]
                .getPublicKey(0,
                    isChange: true, applyTweak: true, isXOnly: true)),
            'bc1p3qkhfews2uk44qtvauqyr2ttdsw7svhkl9nkm9s9c3x4ax5h60wqwruhk7');
      });
    });
    group('getTaprootAddress', () {
      test('Get Taproot address with empty merkle root', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        HDWallet hdWallet = HDWallet(
            null,
            Codec.decodeHex(
                '02d6889cb081036e0faefa3a35157ad71086b123b2b144b649798b494c300a961d'),
            Uint8List.fromList([]));
        Uint8List tPubKey = hdWallet.getPublicKey(true, true);
        expect(AddressType.getP2trTaprootAddress(Codec.encodeHex(tPubKey)),
            'bc1p2wsldez5mud2yam29q22wgfh9439spgduvct83k3pm50fcxa5dps59h4z5');
      });

      test('Get Taproot address with script (case 1)', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        HDWallet hdWallet = HDWallet(
            null,
            Codec.decodeHex(
                '02187791b6f712a8ea41c8ecdd0ee77fab3e85263b37e1ec18a3651926b3a6cf27'),
            Uint8List.fromList([]));
        Uint8List tPubKey = hdWallet.getPublicKey(true, true,
            merkleRoot: Codec.decodeHex(
                '5b75adecf53548f3ec6ad7d78383bf84cc57b55a3127c72b9a2481752dd88b21'));
        expect(
            AddressType.getTaprootAddressFromTweakedPublicKey(
                Codec.encodeHex(tPubKey)),
            'bc1pz37fc4cn9ah8anwm4xqqhvxygjf9rjf2resrw8h8w4tmvcs0863sa2e586');
      });
      test('Get Taproot address with script (case 2)', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        HDWallet hdWallet = HDWallet(
            null,
            Codec.decodeHex(
                '0293478e9488f956df2396be2ce6c5cced75f900dfa18e7dabd2428aae78451820'),
            Uint8List.fromList([]));
        Uint8List tPubKey = hdWallet.getPublicKey(true, true,
            merkleRoot: Codec.decodeHex(
                'c525714a7f49c28aedbbba78c005931a81c234b2f6c99a73e4d06082adc8bf2b'));
        expect(
            AddressType.getTaprootAddressFromTweakedPublicKey(
                Codec.encodeHex(tPubKey)),
            'bc1punvppl2stp38f7kwv2u2spltjuvuaayuqsthe34hd2dyy5w4g58qqfuag5');
      });
    });

    group('getTaprootAddress', () {
      String getOutputKey(String internalKey, String merkleRoot) {
        Uint8List keyToTweak = Codec.decodeHex(internalKey);
        Uint8List merkleRootBytes = Codec.decodeHex(merkleRoot);
        Uint8List hashTapTweak =
            Hash.hashTapTweak('TapTweak', keyToTweak, merkleRootBytes);

        Uint8List tweakedPubKey =
            Ecc.pointAddScalar(keyToTweak, hashTapTweak, true)!;

        if (tweakedPubKey[0] == 0x03) {
          tweakedPubKey = Ecc.pointNegate(tweakedPubKey)!;
        }

        Uint8List outputKey = tweakedPubKey.sublist(1);
        return Codec.encodeHex(outputKey);
      }

      test('Get Taproot address with merkle root (case 1)', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        // Internal key (x-only, 32 bytes)
        String internalKey =
            '187791b6f712a8ea41c8ecdd0ee77fab3e85263b37e1ec18a3651926b3a6cf27';
        String merkleRoot =
            '5b75adecf53548f3ec6ad7d78383bf84cc57b55a3127c72b9a2481752dd88b21';
        String address = AddressType.getP2trTaprootAddress(
            getOutputKey(internalKey, merkleRoot));
        expect(address,
            'bc1pz37fc4cn9ah8anwm4xqqhvxygjf9rjf2resrw8h8w4tmvcs0863sa2e586');
      });

      test('Get Taproot address with merkle root (case 2)', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        // Internal key (x-only, 32 bytes)
        String internalKey =
            '93478e9488f956df2396be2ce6c5cced75f900dfa18e7dabd2428aae78451820';
        String merkleRoot =
            'c525714a7f49c28aedbbba78c005931a81c234b2f6c99a73e4d06082adc8bf2b';
        String address = AddressType.getP2trTaprootAddress(
            getOutputKey(internalKey, merkleRoot));
        expect(address,
            'bc1punvppl2stp38f7kwv2u2spltjuvuaayuqsthe34hd2dyy5w4g58qqfuag5');
      });

      test('Get Taproot address on testnet', () {
        NetworkType.setNetworkType(NetworkType.testnet);
        String internalKey =
            'd6889cb081036e0faefa3a35157ad71086b123b2b144b649798b494c300a961d';
        String address = AddressType.getP2trTaprootAddress(internalKey);
        expect(address, startsWith('tb1p'));
      });

      test('Get Taproot address on regtest', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        String internalKey =
            'd6889cb081036e0faefa3a35157ad71086b123b2b144b649798b494c300a961d';
        String address = AddressType.getP2trTaprootAddress(internalKey);
        expect(address, startsWith('bcrt1p'));
      });
    });

    group('getMultisignatureAddress', () {
      test('getP2shAddress', () {
        NetworkType.setNetworkType(NetworkType.mainnet);

        expect(
            AddressType.p2sh.getMultisignatureAddress([
              '02d22360accac12f6804a1e3bc2fa2a9e6bce1d48647f829a8fc5e64577d48ea86',
              '02d0a35af9057b528adf181a00876dd0d2cee241cf1b2ce0719e8c4ed9939b99f2',
              '02a8c51b0ba20e9262291b8002112f9892069355049cade351f15f62e64668ce38'
            ], 2),
            '37Y7Ci36ZzwmxfUt6vrnz1RDrEFp7EtdRE');
      });
      test('getP2wshAddress', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(
            AddressType.p2wsh.getMultisignatureAddress([
              '02ecb68401036cf502e80e15e0876f1f62627e933c97b1d2d2ebedb9e5b88f562e',
              '021f4a8611bc27942b8f80fb25a2d66c3fd82739bb672909ec519a4f7aac36588b',
              '03c6382a22a126247191d45ef5742f8315c93e1de73eab0ac025c55bbfb18dfb54'
            ], 2),
            'bc1qa8y7pfegg6de9z5ffquq2eeqdf5qhr7dujeec3t654tcch9uvmyqyz3h36');
      });

      test('getWrongMultisigatureAddress', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(
            () => AddressType.p2wpkh.getMultisignatureAddress([
                  '02ecb68401036cf502e80e15e0876f1f62627e933c97b1d2d2ebedb9e5b88f562e',
                  '021f4a8611bc27942b8f80fb25a2d66c3fd82739bb672909ec519a4f7aac36588b',
                  '03c6382a22a126247191d45ef5742f8315c93e1de73eab0ac025c55bbfb18dfb54'
                ], 2),
            throwsException);
      });

      test('rejects duplicate public keys and invalid threshold', () {
        const publicKey =
            '02ecb68401036cf502e80e15e0876f1f62627e933c97b1d2d2ebedb9e5b88f562e';

        expect(
            () => AddressType.p2wsh
                .getMultisignatureAddress([publicKey, publicKey], 1),
            throwsException);
        expect(() => AddressType.p2wsh.getMultisignatureAddress([publicKey], 0),
            throwsException);
        expect(() => AddressType.p2sh.getMultisignatureAddress([publicKey], 2),
            throwsException);
      });
    });

    group('getP2trScriptPathSpendingAddress', () {
      final publicKeys = [
        '187791b6f712a8ea41c8ecdd0ee77fab3e85263b37e1ec18a3651926b3a6cf27',
        '93478e9488f956df2396be2ce6c5cced75f900dfa18e7dabd2428aae78451820',
      ];

      test('creates addresses for n-of-n and threshold scripts', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(AddressType.getP2trScriptPathSpendingAddress([...publicKeys], 2),
            startsWith('bc1p'));
        expect(AddressType.getP2trScriptPathSpendingAddress([...publicKeys], 1),
            startsWith('bc1p'));
      });

      test('rejects unsupported signature thresholds', () {
        expect(
            () => AddressType.getP2trScriptPathSpendingAddress(
                [...publicKeys, ...publicKeys], 4),
            throwsException);
        expect(
            () => AddressType.getP2trScriptPathSpendingAddress(
                [...publicKeys], 3),
            throwsException);
      });

      test('rejects non-x-only public keys', () {
        expect(
            () => AddressType.getP2trScriptPathSpendingAddress(
                ['02${publicKeys.first}'], 1),
            throwsException);
      });
    });
    group('operator ==', () {
      test('operator ==', () {
        expect(AddressType.p2pkh == AddressType.p2pkh, true);
        expect(AddressType.p2pkh == AddressType.p2wpkh, false);
      });
      test('hashCode', () {
        expect(AddressType.p2pkh.hashCode == AddressType.p2pkh.hashCode, true);
        expect(
            AddressType.p2pkh.hashCode == AddressType.p2wpkh.hashCode, false);
      });
    });
    group('toString', () {
      test('toString', () {
        expect(AddressType.p2pkh.toString(), 'pkh');
        expect(AddressType.p2wpkh.toString(), 'wpkh');
        expect(AddressType.p2sh.toString(), 'sh');
        expect(AddressType.p2wsh.toString(), 'wsh');
        expect(AddressType.p2tr.toString(), 'tr');
      });
    });
  });
}
