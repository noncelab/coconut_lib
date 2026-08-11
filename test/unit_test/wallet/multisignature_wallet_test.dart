@Tags(['unit'])
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../mock_factory.dart';

void main() async {
  group('MultisignatureWallet', () {
    late MultisignatureVault vault;
    setUpAll(() async {
      NetworkType.setNetworkType(NetworkType.regtest);
      vault = MockFactory.createP2wshVault();
    });
    group('MultisignatureWallet.fromDescriptor', () {
      test('stores independent public-only key stores', () {
        final publicKeyStores = vault.keyStoreList
            .map((keyStore) => KeyStore.fromExtendedPublicKey(
                keyStore.extendedPublicKey.serialize(),
                keyStore.masterFingerprint))
            .toList();
        final wallet = MultisignatureWallet(vault.requiredSignature,
            vault.addressType, vault.derivationPath, publicKeyStores);

        expect(wallet.keyStoreList, isNot(same(publicKeyStores)));
        for (int i = 0; i < publicKeyStores.length; i++) {
          expect(wallet.keyStoreList[i], isNot(same(publicKeyStores[i])));
          expect(wallet.keyStoreList[i].hdWallet.isNeutered(), isTrue);
          expect(wallet.keyStoreList[i].hasSeed, isFalse);
        }
        expect(() => wallet.keyStoreList.clear(), throwsUnsupportedError);
      });

      test('Generate multisignature wallet from descriptor', () {
        String descriptor = vault.descriptor;
        MultisignatureWallet wallet =
            MultisignatureWallet.fromDescriptor(descriptor);
        expect(wallet.requiredSignature, vault.requiredSignature);
        expect(wallet.addressType, vault.addressType);
        expect(wallet.derivationPath, vault.derivationPath);
        expect(wallet.keyStoreList.length, vault.keyStoreList.length);
        for (int i = 0; i < wallet.keyStoreList.length; i++) {
          expect(wallet.keyStoreList[i].extendedPublicKey.serialize(),
              vault.keyStoreList[i].extendedPublicKey.serialize());
        }
      });

      test('Reject duplicate account xpub and invalid threshold', () {
        final expressions = vault.keyStoreList
            .map((keyStore) => Descriptor.getKeyOriginExpression(
                keyStore, vault.derivationPath))
            .toList();
        final duplicateBody =
            'wsh(sortedmulti(1,${expressions.first},${expressions.first}))';
        final zeroThresholdBody =
            'wsh(sortedmulti(0,${expressions.join(',')}))';

        expect(
            () => MultisignatureWallet.fromDescriptor(duplicateBody,
                ignoreChecksum: true),
            throwsArgumentError);
        expect(
            () => MultisignatureWallet.fromDescriptor(zeroThresholdBody,
                ignoreChecksum: true),
            throwsArgumentError);
      });

      test('Single signature address type exception', () {
        SingleSignatureVault singleSignatureVault =
            MockFactory.createP2wpkhVault();
        expect(
            () => MultisignatureWallet.fromDescriptor(
                singleSignatureVault.descriptor),
            throwsException);
      });
      test('Invalid derivation path (testnet)', () {
        NetworkType.setNetworkType(NetworkType.testnet);
        String descriptor =
            "wsh(sortedmulti(2,[96149E34/48'/0'/0'/2']Vpub5mCBCDqDdmjyJr5UfVAunq9PaifhTVHZYH6gmBey8B2k6TKY9RLoWpej2gAtk3YJQ75LeHgPsaqNZi6tsxn2xwXbiFtt2LZpiiSeeJJym47/<0;1>/*,[360923C9/48'/0'/0'/2']Vpub5mc9AurZMFpRXdnBiR32n5EbX4vWFYwEGUsWUMTp3qhPfTE3NqByjEG9X5FnnCrhd4qSXvx3XEj556ZEj72nm4CUfshR5tTRxmTvJXqB9ct/<0;1>/*,[9BC9E65B/48'/0'/0'/2']Vpub5myh64ZHX7oRm4UEpPRT1Up5wCw1GEJsQjhLKYpQnwoThzvqqYzLAecMi5NbaD4TDe8cuZJWRaUcqWAm4XZ1YVpeDhcJ2Ui2UdRAmivxvGv/<0;1>/*))#l3vjlqwu";
        expect(
            () => MultisignatureWallet.fromDescriptor(descriptor,
                ignoreChecksum: true),
            throwsException);
      });
      test('Invalid derivation path (mainnet)', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        String descriptor =
            "wsh(sortedmulti(2,[96149E34/48'/1'/0'/2']Vpub5mCBCDqDdmjyJr5UfVAunq9PaifhTVHZYH6gmBey8B2k6TKY9RLoWpej2gAtk3YJQ75LeHgPsaqNZi6tsxn2xwXbiFtt2LZpiiSeeJJym47/<0;1>/*,[360923C9/48'/1'/0'/2']Vpub5mc9AurZMFpRXdnBiR32n5EbX4vWFYwEGUsWUMTp3qhPfTE3NqByjEG9X5FnnCrhd4qSXvx3XEj556ZEj72nm4CUfshR5tTRxmTvJXqB9ct/<0;1>/*,[9BC9E65B/48'/1'/0'/2']Vpub5myh64ZHX7oRm4UEpPRT1Up5wCw1GEJsQjhLKYpQnwoThzvqqYzLAecMi5NbaD4TDe8cuZJWRaUcqWAm4XZ1YVpeDhcJ2Ui2UdRAmivxvGv/<0;1>/*))#l3vjlqwu";
        expect(
            () => MultisignatureWallet.fromDescriptor(descriptor,
                ignoreChecksum: true),
            throwsException);
        //     throwsException);
      });

      test('Invalid derivation path (mainnet)', () {
        String descriptor =
            "wpkh([98C7D774/84'/1'/0']vpub5ZZ1q76vi2LR9PeQDoV13u8TZwsyqKa7yBfD3GnPPvBjVU9ZnBTMkwzCHCVBZaPHDKJNEdMKo8MTyrQ9234idzSG9nHFD6hsUB8HJ14NBg7/<0;1>/*)#7ra9g9d8";
        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(() => SingleSignatureWallet.fromDescriptor(descriptor),
            throwsException);
      });

      test('Different derivation exception', () {
        String differentPathDescriptor =
            "wsh(sortedmulti(1,[8EFC895E/48'/1'/0'/2']Vpub5nN5Zc3xDWKyXMbg2mzzAAQ8XgYrh1oaatFMHKv8f2gGcKMaA58YwKZBgarEQKvjs4ZnQ5BoHsLkdvqGRvvP4nLzKHREETB1YnNiMVbyDVa/<0;1>/*,[9DBECA1F/48'/1'/1'/2']Vpub5mKNm4dPgX1USP4jz38ASU7iVdB2XKoafgMKVQz6ZsQt4WoDnyvgMPSicFNDWybjQhohqgpyuHpA7duHRf6Yvx558oSU5g7upR9qffNnQRJ/<0;1>/*))#n3j32yxq";
        expect(
            () => MultisignatureWallet.fromDescriptor(differentPathDescriptor),
            throwsException);
      });
    });

    group('toJson', () {
      test('Get json text from multisignature wallet', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        MultisignatureWallet wallet =
            MultisignatureWallet.fromDescriptor(vault.descriptor);
        String json = wallet.toJson();
        expect(json.hashCode, 1028603620);
      });
    });
    group('MultisignatureWallet.fromJson', () {
      test('MultisignatureWallet.fromJson', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        MultisignatureWallet wallet =
            MultisignatureWallet.fromDescriptor(vault.descriptor);
        String json = wallet.toJson();
        MultisignatureWallet targetWallet = MultisignatureWallet.fromJson(json);

        expect(targetWallet.requiredSignature, wallet.requiredSignature);
        expect(targetWallet.addressType, wallet.addressType);
        expect(targetWallet.derivationPath, wallet.derivationPath);
        expect(targetWallet.keyStoreList.length, wallet.keyStoreList.length);
        for (int i = 0; i < targetWallet.keyStoreList.length; i++) {
          expect(targetWallet.keyStoreList[i].extendedPublicKey.serialize(),
              wallet.keyStoreList[i].extendedPublicKey.serialize());
        }
      });

      test('Reject duplicate account xpub in json', () {
        final expression = Descriptor.getKeyOriginExpression(
            vault.keyStoreList.first, vault.derivationPath);
        final descriptor = 'wsh(sortedmulti(1,$expression,$expression))';

        expect(
            () => MultisignatureWallet.fromJson(
                jsonEncode({'descriptor': descriptor})),
            throwsException);
      });
    });
  });
}
