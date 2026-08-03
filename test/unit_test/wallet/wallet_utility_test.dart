@Tags(['unit'])
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

void main() {
  group('WalletUtility', () {
    group('getDerivationPath', () {
      test('Get standard derivation path of address type', () {
        expect(WalletUtility.getDerivationPath(AddressType.p2wpkh, 0),
            "m/84'/1'/0'");
        expect(WalletUtility.getDerivationPath(AddressType.p2wsh, 0),
            "m/48'/1'/0'/2'");
        expect(WalletUtility.getDerivationPath(AddressType.p2pkh, 0),
            "m/44'/1'/0'");
        expect(WalletUtility.getDerivationPath(AddressType.p2wpkhInP2sh, 0),
            "m/49'/1'/0'");
      });
    });
    group('validateAddress', () {
      test('Validate address due to network type', () {
        NetworkType.setNetworkType(NetworkType.testnet);
        expect(
            WalletUtility.validateAddress(
                "tb1qk4z5ysfc2k72pz2ws4dhskxdq772s7uqc35dp9"),
            true);
        expect(
            WalletUtility.validateAddress(
                "bc1qwa0ccwlyn65jc3w97w0qt93x84y8r4h3ret4mz"),
            false);
        expect(
            WalletUtility.validateAddress(
                "bcrt1qjpdazsu9penqt82sr7z4ln99w8wl5dj0xmulck"),
            true);
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(
            WalletUtility.validateAddress(
                "tb1qk4z5ysfc2k72pz2ws4dhskxdq772s7uqc35dp9"),
            false);
        expect(
            WalletUtility.validateAddress(
                "bc1qwa0ccwlyn65jc3w97w0qt93x84y8r4h3ret4mz"),
            true);
        expect(
            WalletUtility.validateAddress(
                "bcrt1qjpdazsu9penqt82sr7z4ln99w8wl5dj0xmulck"),
            false);
      });
      test('Valid mainnet P2PKH address', () {
        expect(
            WalletUtility.validateAddress('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa'),
            isTrue);
      });

      test('Valid mainnet P2SH address', () {
        expect(
            WalletUtility.validateAddress('3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy'),
            isTrue);
      });

      test('Valid mainnet Bech32 address (P2WPKH)', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(
            WalletUtility.validateAddress(
                'bc1qwa0ccwlyn65jc3w97w0qt93x84y8r4h3ret4mz'),
            true);
      });

      test('Valid mainnet Bech32m address (Taproot)', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(
            WalletUtility.validateAddress(
                'bc1p0n9w6rnw2t77dww8ha32mdcweggr23zdwv9772apnwmv74p22c8slav7sx'),
            isTrue);
      });

      test('Invalid mainnet address with testnet prefix', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(
            WalletUtility.validateAddress(
                'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kygt080'),
            isFalse);
      });

      test('Valid testnet P2PKH address', () {
        NetworkType.setNetworkType(NetworkType.testnet);
        expect(
            WalletUtility.validateAddress('mkD3FXLW5tXVNMTACg5pXpwmbAjR6Y8R7Y'),
            isTrue);
      });

      test('Valid testnet P2SH address', () {
        NetworkType.setNetworkType(NetworkType.testnet);
        expect(
            WalletUtility.validateAddress(
                '2N2JD6wb56AfK4tfmM6PwdVmoYk2dCKf4Br'),
            isTrue);
      });

      test('Valid testnet Bech32 address (P2WPKH)', () {
        NetworkType.setNetworkType(NetworkType.testnet);
        expect(
            WalletUtility.validateAddress(
                'tb1qckwmxscea0rjrqvrhye7djz59nev2e9wgdjvn6'),
            isTrue);
      });

      test('Valid testnet Bech32m address (Taproot)', () {
        NetworkType.setNetworkType(NetworkType.testnet);
        expect(
            WalletUtility.validateAddress(
                'tb1qckwmxscea0rjrqvrhye7djz59nev2e9wgdjvn6'),
            isTrue);
      });

      test('Invalid address with invalid prefix', () {
        expect(
            WalletUtility.validateAddress(
                'zz1qhl6rqwrd99nvky77xyykdrs9hhr2yz37m8ws44'),
            isFalse);
      });

      test('Invalid Bech32 address with wrong hrp', () {
        expect(
            WalletUtility.validateAddress(
                'bc1x508d6qejxtdg4y5r3zarvary0c5xw7kygt080'),
            isFalse);
      });

      test('Invalid Bech32 address with empty data', () {
        expect(WalletUtility.validateAddress('bc1'), isFalse);
      });

      test('Invalid Base58 address with wrong version byte', () {
        expect(
            WalletUtility.validateAddress('4A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa'),
            isFalse);
      });

      test('Invalid Base58 address length', () {
        expect(WalletUtility.validateAddress('1A1zP1eP5QGefi2DMPTfTL5S'),
            isFalse); // Too short
        expect(
            WalletUtility.validateAddress(
                '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNaExtra'),
            isFalse); // Too long
      });

      test('Invalid address with non-alphanumeric characters', () {
        expect(
            WalletUtility.validateAddress(
                '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa!'),
            isFalse);
      });

      test('Valid regtest Bech32 address', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        expect(
            WalletUtility.validateAddress(
                'bcrt1qjpdazsu9penqt82sr7z4ln99w8wl5dj0xmulck'),
            isTrue);
      });

      test('Invalid regtest Bech32 address with mainnet prefix', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        expect(
            WalletUtility.validateAddress(
                'bc1qhl6rqwrd99nvky77xyykdrs9hhr2yz37m8ws44'),
            isFalse);
      });

      test('Invalid Bech32m address with incorrect data type', () {
        expect(
            WalletUtility.validateAddress(
                'bc1p5cyxnuxmeuwuvkwfem96l9yx2gk70hqn5w7z'),
            isFalse); // Data length too short
      });

      test('Invalid Bech32 address with mixed case', () {
        expect(
            WalletUtility.validateAddress(
                'Bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kygt080'),
            isFalse); // Mixed case
      });
    });
    group('isInMnemonicWordList', () {
      test('Check mnemonic word', () {
        expect(WalletUtility.isInMnemonicWordList('abandon'), true);
        expect(WalletUtility.isInMnemonicWordList('abandonz'), false);
      });
    });
    group('validateMnemonic', () {
      test('Check mnemonic validation', () {
        expect(
            WalletUtility.validateMnemonic(utf8.encode(
                'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about')),
            true);
        expect(
            WalletUtility.validateMnemonic(utf8.encode(
                'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon')),
            false);
      });
      test('Test mnemonic validation exception', () {
        String wrongMnemonic1 =
            'eagle hedgehog then coral type message loyal blanket hundred ritual flock zebra mammal above dial senior easy hope canoe myth neck number face abandon';
        String wrongMnemonic2 =
            'rib reward pill favorite expect elder cash patient hour bird genius myth';
        String wrongMnemonic3 =
            'wise tragic potato piece tail intact second bird ignore absent sleep attract cradle double arm';
        String wrongMnemonic4 =
            'foster across update trigger grid print choose tag water secon system town';
        expect(
            WalletUtility.validateMnemonic(utf8.encode(wrongMnemonic1)), false);
        expect(
            WalletUtility.validateMnemonic(utf8.encode(wrongMnemonic2)), false);
        expect(
            WalletUtility.validateMnemonic(utf8.encode(wrongMnemonic3)), false);
        expect(
            WalletUtility.validateMnemonic(utf8.encode(wrongMnemonic4)), false);
      });
    });
    group('validateDerivationPath', () {
      test("Valid derivation path (standard)", () {
        expect(WalletUtility.validateDerivationPath("m/44'/0'/0'/0/0"), isTrue);
      });

      test("Valid derivation path with h", () {
        expect(WalletUtility.validateDerivationPath("m/44h/0h/0h/0/0"), isTrue);
      });

      test("Valid derivation path with hardened keys only", () {
        expect(WalletUtility.validateDerivationPath("m/44'/1'/0'"), isTrue);
      });

      test("Valid derivation path with no sub-paths", () {
        expect(WalletUtility.validateDerivationPath("m"), isTrue);
      });

      test("Invalid derivation path with wrong prefix", () {
        expect(
            WalletUtility.validateDerivationPath("n/44'/0'/0'/0/0"), isFalse);
      });

      test("Invalid derivation path with non-numeric segment", () {
        expect(
            WalletUtility.validateDerivationPath("m/44'/x'/0'/0/0"), isFalse);
      });

      test("Invalid derivation path with negative index", () {
        expect(
            WalletUtility.validateDerivationPath("m/44'/-1/0'/0/0"), isFalse);
      });

      test("Invalid derivation path with number out of range", () {
        expect(WalletUtility.validateDerivationPath("m/44'/2147483648/0'/0/0"),
            isFalse); // 2^31
      });

      test("Invalid derivation path with empty segment", () {
        expect(WalletUtility.validateDerivationPath("m/44'//0'/0/0"), isFalse);
      });

      test("Invalid derivation path with trailing slash", () {
        expect(
            WalletUtility.validateDerivationPath("m/44'/0'/0'/0/0/"), isFalse);
      });

      test("Invalid derivation path with missing m prefix", () {
        expect(WalletUtility.validateDerivationPath("/44'/0'/0'/0/0"), isFalse);
      });

      test("Invalid derivation path with spaces", () {
        expect(WalletUtility.validateDerivationPath("m /44' /0'/ 0'/0/0"),
            isFalse);
      });

      test("Valid derivation path with maximum number", () {
        expect(WalletUtility.validateDerivationPath("m/44'/2147483647/0'/0/0"),
            isTrue); // 2^31-1
      });
    });
    group('satoshiToBitcoin', () {
      test('converts satoshi to bitcoin', () {
        expect(WalletUtility.satoshiToBitcoin(123456789), 1.23456789);
      });
    });
    group('bitcoinToSatoshi', () {
      test('converts bitcoin to satoshi without floating-point drift', () {
        expect(WalletUtility.bitcoinToSatoshi(1.23456789), 123456789);
      });
    });
    group('getAccountIndexFromDerivationPath', () {
      test('returns the final path component', () {
        expect(WalletUtility.getAccountIndexFromDerivationPath('m/84/1/7'), 7);
      });
    });
    group('isChangeFromDerivationPath', () {
      test('detects receive and change branches', () {
        expect(
            WalletUtility.isChangeFromDerivationPath('m/84/1/0/1/3'), isTrue);
        expect(
            WalletUtility.isChangeFromDerivationPath('m/84/1/0/0/3'), isFalse);
      });
    });

    group('estimateVirtualByte', () {
      test('requires multisignature parameters for p2wsh', () {
        expect(() => WalletUtility.estimateVirtualByte(AddressType.p2wsh, 1, 2),
            throwsArgumentError);
      });

      test('estimates taproot key-path spending', () {
        expect(
            WalletUtility.estimateVirtualByte(AddressType.p2tr, 1, 2), 137.5);
      });

      test('estimates taproot script-path spending', () {
        expect(
            WalletUtility.estimateVirtualByte(AddressType.p2tr, 1, 2,
                isScriptPath: true,
                requiredSignature: 2,
                leafCount: 4,
                tapScriptSize: 68),
            greaterThan(
                WalletUtility.estimateVirtualByte(AddressType.p2tr, 1, 2)));
      });

      test('requires taproot script-path metadata', () {
        expect(
            () => WalletUtility.estimateVirtualByte(AddressType.p2tr, 1, 2,
                isScriptPath: true),
            throwsArgumentError);
      });

      test('rejects unsupported legacy address types', () {
        expect(() => WalletUtility.estimateVirtualByte(AddressType.p2pkh, 1, 2),
            throwsException);
      });
      test('Estimate virtual byte for p2wpkh', () {
        Transaction transaction = Transaction.parse(
            '02000000000101e651891f611e71f59151325620d01b40808c6eab359cdc4164008fd02366db190100000000fdffffff025bfd100300000000160014192e80ed2c7c412bdc2a6c8f371d15cb90f3c85bb3ff0200000000001600142aa810d27d2f384feadab9fdda547678fbc9939e024730440220320a44fc713353c149b37f6f8b32e77ca79586cd0d84799ca3095feec143c02b0220025da285e3f22804dd3a8824aca745fa8d01ef8eac9f27bbc53ff9a13b038000012103b01bd095f648ea829f000207087f16622431077bb5cc0875225ada601375c88500000000');
        int tolerance = transaction.inputs.length * 2;
        tolerance = transaction.outputs.length * 5;
        expect(
            WalletUtility.estimateVirtualByte(AddressType.p2wpkh,
                transaction.inputs.length, transaction.outputs.length),
            inInclusiveRange(transaction.getVirtualByte() - tolerance,
                transaction.getVirtualByte() + tolerance));
      });

      test('Estimate virtual byte for p2wsh', () {
        Transaction transaction = Transaction.parse(
            '010000000001016ac6a4a7967d8ef65e06b89b876b5916790c0d2e9aa47403e3aa495fd698435d0300000000ffffffff0400366e0100000000160014df9ceb5a5535fbb3f271d7fac54a4f16051a3085f76fd2010000000017a9141d2e927680fdcaf127501f968c7bdea5ed5d96de876b90b70200000000160014417b365c93b581ec927aaa316c8b55abff17f8e486ab4a0b00000000220020701a8d401c84fb13e6baf169d59684e17abd9fa216c8cc5b9fc63d622ff8c58d04004730440220312fed48b206af9f4fc6fef9800ffd337c52dbf2180a28d85d94b595eba604410220379f772b93c0dea29f40cb9425b517bb55192e26396c4779b2129d11ec073a430147304402204f286ed4c8e8d2037a2d36037ac3c9cc3f856fb2d6a078c703e5df5e98377b2402203f9f8d10866c9476321d37e18305ff25a976f61d61bd0cd9957139cb939035ff016952210279d1f38c1c80d47cb00ddbbe2915a60d5706e1ef66056a169150f083b288eb952102cb7d02b654f8616bfc5ab017b7a3ec9092e466381af0f552b7efcd8d920453672103c96d495bfdd5ba4145e3e046fee45e84a8a48ad05bd8dbb395c011a32cf9f88053ae00000000');
        int requiredSignature = 2;
        int totalSigner = 3;
        int tolerance = transaction.inputs.length * requiredSignature * 2;
        tolerance = transaction.outputs.length * 5;
        expect(
            WalletUtility.estimateVirtualByte(AddressType.p2wsh,
                transaction.inputs.length, transaction.outputs.length,
                requiredSignature: requiredSignature, totalSigner: totalSigner),
            inInclusiveRange(transaction.getVirtualByte() - tolerance,
                transaction.getVirtualByte() + tolerance));
      });
    });
  });
}
