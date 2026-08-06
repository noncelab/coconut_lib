@Tags(['unit'])
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../mock_factory.dart';

void main() {
  group('KeyStore', () {
    late Seed seed;
    late KeyStore keyStore;

    setUpAll(() async {
      seed = Seed.fromMnemonic(utf8.encode(
          "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"));
      keyStore = KeyStore.fromSeed(seed, AddressType.p2wpkh);
    });
    group('masterFingerprint', () {
      test('returns the root key fingerprint', () {
        expect(keyStore.masterFingerprint, hasLength(8));
      });
    });
    group('hdWallet', () {
      test('returns the account-level HD wallet', () {
        expect(
            keyStore.hdWallet.publicKey, keyStore.extendedPublicKey.publicKey);
      });
    });
    group('getChildHdWallet', () {
      test('returns distinct receive and change branches', () {
        expect(Codec.encodeHex(keyStore.getChildHdWallet(false).publicKey),
            isNot(Codec.encodeHex(keyStore.getChildHdWallet(true).publicKey)));
      });
    });
    group('extendedPublicKey', () {
      test('returns the account extended public key', () {
        expect(
            keyStore.extendedPublicKey.publicKey, keyStore.hdWallet.publicKey);
      });
    });
    group('seed', () {
      test('returns the bound seed', () {
        expect(keyStore.seed, seed);
      });

      test('binds and removes a seed', () {
        final watchOnly = KeyStore.fromExtendedPublicKey(
            keyStore.extendedPublicKey.serialize(), keyStore.masterFingerprint);
        watchOnly.seed = seed;
        expect(watchOnly.seed, seed);
        watchOnly.seed = null;
        expect(watchOnly.hasSeed, isFalse);
      });
    });
    group('hasSeed', () {
      test('reports whether private seed material is available', () {
        final watchOnly = KeyStore.fromExtendedPublicKey(
            keyStore.extendedPublicKey.serialize(), keyStore.masterFingerprint);
        expect(keyStore.hasSeed, isTrue);
        expect(watchOnly.hasSeed, isFalse);
      });
    });
    group('hasSamePublicIdentity', () {
      test('matches a watch-only key store for the same account key', () {
        final watchOnly = KeyStore.fromExtendedPublicKey(
            keyStore.extendedPublicKey.serialize(), keyStore.masterFingerprint);

        expect(keyStore.hasSamePublicIdentity(watchOnly), true);
      });

      test('rejects another account key with the same fingerprint', () {
        final other = KeyStore.fromSeed(
            MockFactory.getCommonSeed(passphrase: 'different'),
            AddressType.p2wpkh);
        final fingerprintCollision = KeyStore(keyStore.masterFingerprint,
            other.hdWallet, other.extendedPublicKey);

        expect(keyStore.hasSamePublicIdentity(fingerprintCollision), false);
      });
    });
    group('fromSeed', () {
      test('Generate key store from seed', () {
        expect(keyStore, isA<KeyStore>());
        expect(keyStore.seed, seed);
        expect(keyStore.extendedPublicKey.serialize(),
            'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc');
      });
      test('Generate key store from seed with passphrase', () {
        Seed seedWithPassphrase = Seed.fromMnemonic(
            utf8.encode(
                "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"),
            passphrase: utf8.encode('passphrase'));
        KeyStore keyStoreWithPassphrase =
            KeyStore.fromSeed(seedWithPassphrase, AddressType.p2wpkh);
        expect(keyStoreWithPassphrase.seed, seedWithPassphrase);
        expect(keyStoreWithPassphrase.extendedPublicKey.serialize(),
            'vpub5ZKwzd8dsRkgfWuhHHxC1gv8KqJSGks821gx5sKBVAHco8TccsdMh6X4jiWjeTGW4SpkK77dP3HPEpZjgxzpGGq1G53NU7ftHhRfbijqxvf');
      });
    });
    group('fromMnemonic', () {
      test('Generate key store with mnemonic', () {
        KeyStore keyStore = KeyStore.fromMnemonic(
            utf8.encode(
                "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"),
            AddressType.p2wpkh);
        expect(keyStore, isA<KeyStore>());
        expect(keyStore.extendedPublicKey.serialize(),
            'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc');
      });
    });
    group('random', () {
      test('Generate random key store', () {
        KeyStore keyStore = KeyStore.random(AddressType.p2wpkh);
        expect(keyStore, isA<KeyStore>());
      });
    });
    group('fromEntropy', () {
      test('Generate key store from entropy', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        KeyStore keyStore = KeyStore.fromEntropy(
            Codec.decodeHex("00000000000000000000000000000000"),
            AddressType.p2wpkh);
        expect(keyStore, isA<KeyStore>());
        expect(keyStore.extendedPublicKey.serialize(),
            'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs');
      });
    });
    group('fromExtendedPublicKey', () {
      test('Generate key store from extended public key', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        String exPub =
            'Vpub5n3ihNrEwZjBFZ32N6STEsMaUPAJ42pjoVMgbZUAuPbuubQR5eDXUyB8nw6ASMmzpM4PjyVsx6BHGhZwufeyVzCHxwLcXW5RoQ5feCiE6Qm';
        KeyStore keyStore = KeyStore.fromExtendedPublicKey(exPub, 'ae2e1224');
        expect(keyStore.extendedPublicKey.serialize(), exPub);
      });
    });
    group('fromSignerBsms', () {
      test('Generate key store from signer', () {
        String bsms =
            '''BSMS 1.0\n00\n[98C7D774/48'/1'/0'/2']Vpub5n3ihNrEwZjBFZ32N6STEsMaUPAJ42pjoVMgbZUAuPbuubQR5eDXUyB8nw6ASMmzpM4PjyVsx6BHGhZwufeyVzCHxwLcXW5RoQ5feCiE6Qm\nmy wallet''';
        KeyStore keyStore = KeyStore.fromSignerBsms(bsms);
        expect(keyStore, isA<KeyStore>());
        expect(keyStore.extendedPublicKey.serialize(),
            'Vpub5n3ihNrEwZjBFZ32N6STEsMaUPAJ42pjoVMgbZUAuPbuubQR5eDXUyB8nw6ASMmzpM4PjyVsx6BHGhZwufeyVzCHxwLcXW5RoQ5feCiE6Qm');
      });
    });
    group('getPrivateKey', () {
      test('Get private key (receive)', () {
        // String privateKey = '3uhZVhK22HgcQQjun7Uysc2cTZGqLDuiSUXnJMUWtLQvo44';
        expect(keyStore.getPrivateKey(0),
            'a9c4134b73560f43fc5c081e5c1daa7ce068adc806d80e1f37cb658e0fea4c8d');
      });
      test('Get private key (change)', () {
        // String privateKey = '3uDFZxBEWBcRjAMMzjbSmXiX869rUg26FnYN22RxtsP8ojE';
        expect(keyStore.getPrivateKey(0, isChange: true),
            '4a78147e621966ebca7185d7567a5db3c91af2d45455dba8e350b34f66187d64');
      });
    });

    group('getPublicKey', () {
      test('Get public key', () {
        expect(keyStore.getPublicKey(0),
            '02e7ab2537b5d49e970309aae06e9e49f36ce1c9febbd44ec8e0d1cca0b4f9c319');
      });
      test('Get public key for change', () {
        expect(keyStore.getPublicKey(0, isChange: true),
            '035d49eccd54d0099e43676277c7a6d4625d611da88a5df49bf9517a7791a777a5');
      });
      test('Get public key for schnorr', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        SingleSignatureVault vault = SingleSignatureVault.fromMnemonic(
            utf8.encode(
                "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"),
            addressType: AddressType.p2tr);
        expect(
            vault.keyStore.getPublicKey(0,
                isChange: false, applyTweak: true, isXOnly: true),
            'a60869f0dbcf1dc659c9cecbaf8050135ea9e8cdc487053f1dc6880949dc684c');
      });
    });

    group('hasPublicKeyInPsbt', () {
      test('Check sign possibility with wrong key store', () {
        Psbt psbt = MockFactory.createP2wpkhUnsignedPsbt();
        expect(keyStore.hasPublicKeyInPsbt(psbt.serialize()), false);
      });
      test('Check sign possibility with right key store', () {
        Psbt psbt = MockFactory.createP2wpkhUnsignedPsbt();

        expect(
            MockFactory.createP2wpkhVault()
                .keyStore
                .hasPublicKeyInPsbt(psbt.serialize()),
            true);
      });
    });
    group('addSignatureToPsbt', () {
      test('Sign to PSBT (single signature)', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        Psbt unsignedPsbt = MockFactory.createP2wpkhUnsignedPsbt();
        SingleSignatureVault vault = MockFactory.createP2wpkhVault();

        String signedPsbtText = vault.keyStore
            .addSignatureToPsbt(unsignedPsbt.serialize(), vault.addressType);
        expect(Psbt.parse(signedPsbtText).serialize(), signedPsbtText);
      });
      test('Sign to PSBT (multisignature)', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        Psbt unsignedPsbt = MockFactory.createP2wshUnsignedPsbt();
        MultisignatureVault vault = MockFactory.createP2wshVault();
        String partialSignedPsbtText = vault.keyStoreList[0]
            .addSignatureToPsbt(unsignedPsbt.serialize(), vault.addressType);
        String signedPsbtText = vault.keyStoreList[1]
            .addSignatureToPsbt(partialSignedPsbtText, vault.addressType);

        expect(Psbt.parse(signedPsbtText).serialize(), signedPsbtText);
      });
      test('Sign to PSBT (MuSig2)', () {
        KeyStore keyStore1 = KeyStore.fromSeed(
            MockFactory.getCommonSeed(passphrase: 'A'), AddressType.p2tr);
        KeyStore keyStore2 = KeyStore.fromSeed(
            MockFactory.getCommonSeed(passphrase: 'B'), AddressType.p2tr);
        TaprootVault vault =
            TaprootVault.fromKeyStoreList([keyStore1, keyStore2], []);
        Transaction tx = Transaction.forSinglePayment(
            MockFactory.createTaprootUtxoList(count: 1),
            vault.getAddress(1),
            '${vault.derivationPath}/1/1',
            15000,
            3,
            vault);
        String psbt = Psbt.fromTransaction(tx, vault).serialize();
        String noncePsbt = vault.addPublicNonce(psbt);
        String signedPsbtText =
            keyStore1.addSignatureToPsbt(noncePsbt, AddressType.p2tr);
        Psbt signedPsbt = Psbt.parse(signedPsbtText);
        expect(signedPsbt.isSigned(keyStore1), true);
      });

      test('MuSig2 secret nonce cannot be consumed twice', () {
        KeyStore keyStore1 = KeyStore.fromSeed(
            MockFactory.getCommonSeed(passphrase: 'A'), AddressType.p2tr);
        KeyStore keyStore2 = KeyStore.fromSeed(
            MockFactory.getCommonSeed(passphrase: 'B'), AddressType.p2tr);
        TaprootVault vault =
            TaprootVault.fromKeyStoreList([keyStore1, keyStore2], []);
        Transaction tx = Transaction.forSinglePayment(
            MockFactory.createTaprootUtxoList(count: 1),
            vault.getAddress(1),
            '${vault.derivationPath}/1/1',
            15000,
            3,
            vault);
        String noncePsbt =
            vault.addPublicNonce(Psbt.fromTransaction(tx, vault).serialize());

        keyStore1.addSignatureToPsbt(noncePsbt, AddressType.p2tr);

        expect(
            () => keyStore1.addSignatureToPsbt(noncePsbt, AddressType.p2tr),
            throwsA(isA<StateError>().having((error) => error.message,
                'message', contains('already been consumed'))));
      });

      test('MuSig2 signing rejects a nonce after KeyStore restoration', () {
        KeyStore keyStore1 = KeyStore.fromSeed(
            MockFactory.getCommonSeed(passphrase: 'A'), AddressType.p2tr);
        KeyStore keyStore2 = KeyStore.fromSeed(
            MockFactory.getCommonSeed(passphrase: 'B'), AddressType.p2tr);
        TaprootVault vault =
            TaprootVault.fromKeyStoreList([keyStore1, keyStore2], []);
        Transaction tx = Transaction.forSinglePayment(
            MockFactory.createTaprootUtxoList(count: 1),
            vault.getAddress(1),
            '${vault.derivationPath}/1/1',
            15000,
            3,
            vault);
        Psbt noncePsbt = Psbt.parse(
            vault.addPublicNonce(Psbt.fromTransaction(tx, vault).serialize()));
        KeyStore restoredKeyStore = KeyStore.fromSeed(
            MockFactory.getCommonSeed(passphrase: 'A'), AddressType.p2tr);

        expect(
            () => restoredKeyStore.addSignatureToPsbt(
                noncePsbt.serialize(), AddressType.p2tr),
            throwsA(isA<StateError>().having(
                (error) => error.message, 'message', contains('unavailable'))));
      });

      test('MuSig2 nonce can be safely replaced before signing', () {
        KeyStore keyStore1 = KeyStore.fromSeed(
            MockFactory.getCommonSeed(passphrase: 'A'), AddressType.p2tr);
        KeyStore keyStore2 = KeyStore.fromSeed(
            MockFactory.getCommonSeed(passphrase: 'B'), AddressType.p2tr);
        TaprootVault vault =
            TaprootVault.fromKeyStoreList([keyStore1, keyStore2], []);
        Transaction tx = Transaction.forSinglePayment(
            MockFactory.createTaprootUtxoList(count: 1),
            vault.getAddress(1),
            '${vault.derivationPath}/1/1',
            15000,
            3,
            vault);
        String unsignedPsbt = Psbt.fromTransaction(tx, vault).serialize();
        String firstNoncePsbt = vault.addPublicNonce(unsignedPsbt);
        String replacementNoncePsbt = vault.addPublicNonce(firstNoncePsbt);

        expect(
            Psbt.parse(replacementNoncePsbt).inputs.single.muSig2PubNonces,
            isNot(equals(
                Psbt.parse(firstNoncePsbt).inputs.single.muSig2PubNonces)));

        String signedPsbt = vault.addSignatureToPsbt(replacementNoncePsbt);
        expect(
            () => Psbt.parse(signedPsbt).getSignedTransaction(AddressType.p2tr),
            returnsNormally);
      });
    });

    group('calculateSecretNonce', () {
      //Test vector from https://github.com/bitcoin/bips/blob/master/bip-0327/vectors/nonce_gen_vectors.json
      test('Generate secret nonce (deterministic case)', () {
        Uint8List rand = Codec.decodeHex(
            '659da54c7b484598ba29fb2600b9e400a8e4536de1f69906fec3549156f4223f');
        Uint8List secretKey = Codec.decodeHex(
            '0202020202020202020202020202020202020202020202020202020202020202');
        Uint8List publicKey = Codec.decodeHex(
            "024D4B6CD1361032CA9BD2AEB9D900AA4D45D9EAD80AC9423374C451A7254D0766");
        Uint8List aggPubkey = Codec.decodeHex(
            "0707070707070707070707070707070707070707070707070707070707070707");
        Uint8List message = Codec.decodeHex(
            "0101010101010101010101010101010101010101010101010101010101010101");
        Uint8List extraInput = Codec.decodeHex(
            "0808080808080808080808080808080808080808080808080808080808080808");

        String secretNonce = Codec.encodeHex(KeyStore.calculateSecretNonce(
            rand, secretKey, publicKey, aggPubkey, message, extraInput));
        expect(secretNonce.toUpperCase(),
            'B114E502BEAA4E301DD08A50264172C84E41650E6CB726B410C0694D59EFFB6495B5CAF28D045B973D63E3C99A44B807BDE375FD6CB39E46DC4A511708D0E9D2024D4B6CD1361032CA9BD2AEB9D900AA4D45D9EAD80AC9423374C451A7254D0766');
      });

      test('Generate secret nonce (non deterministic case 1)', () {
        Uint8List rand = Codec.decodeHex(
            '0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F');
        Uint8List secretKey = Codec.decodeHex(
            '0202020202020202020202020202020202020202020202020202020202020202');
        Uint8List publicKey = Codec.decodeHex(
            "024D4B6CD1361032CA9BD2AEB9D900AA4D45D9EAD80AC9423374C451A7254D0766");
        Uint8List aggPubkey = Codec.decodeHex(
            "0707070707070707070707070707070707070707070707070707070707070707");
        Uint8List message = Codec.decodeHex(
            "0101010101010101010101010101010101010101010101010101010101010101");
        Uint8List extraInput = Codec.decodeHex(
            "0808080808080808080808080808080808080808080808080808080808080808");

        String secretNonce = Codec.encodeHex(KeyStore.calculateSecretNonce(
            rand, secretKey, publicKey, aggPubkey, message, extraInput,
            isDeterministic: false));
        expect(secretNonce.toUpperCase(),
            'B114E502BEAA4E301DD08A50264172C84E41650E6CB726B410C0694D59EFFB6495B5CAF28D045B973D63E3C99A44B807BDE375FD6CB39E46DC4A511708D0E9D2024D4B6CD1361032CA9BD2AEB9D900AA4D45D9EAD80AC9423374C451A7254D0766');
      });

      test('Generate secret nonce (non deterministic case 2)', () {
        Uint8List rand = Codec.decodeHex(
            '0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F');
        Uint8List secretKey = Codec.decodeHex(
            '0202020202020202020202020202020202020202020202020202020202020202');
        Uint8List publicKey = Codec.decodeHex(
            "024D4B6CD1361032CA9BD2AEB9D900AA4D45D9EAD80AC9423374C451A7254D0766");
        Uint8List aggPubkey = Codec.decodeHex(
            "0707070707070707070707070707070707070707070707070707070707070707");
        Uint8List message = Codec.decodeHex("");
        Uint8List extraInput = Codec.decodeHex(
            "0808080808080808080808080808080808080808080808080808080808080808");

        String secretNonce = Codec.encodeHex(KeyStore.calculateSecretNonce(
            rand, secretKey, publicKey, aggPubkey, message, extraInput,
            isDeterministic: false));
        expect(secretNonce.toUpperCase(),
            'E862B068500320088138468D47E0E6F147E01B6024244AE45EAC40ACE5929B9F0789E051170B9E705D0B9EB49049A323BBBBB206D8E05C19F46C6228742AA7A9024D4B6CD1361032CA9BD2AEB9D900AA4D45D9EAD80AC9423374C451A7254D0766');
      });
      test('Generate secret nonce (non deterministic case 3)', () {
        Uint8List rand = Codec.decodeHex(
            '0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F');
        Uint8List secretKey = Codec.decodeHex(
            '0202020202020202020202020202020202020202020202020202020202020202');
        Uint8List publicKey = Codec.decodeHex(
            "024D4B6CD1361032CA9BD2AEB9D900AA4D45D9EAD80AC9423374C451A7254D0766");
        Uint8List aggPubkey = Codec.decodeHex(
            "0707070707070707070707070707070707070707070707070707070707070707");
        Uint8List message = Codec.decodeHex(
            "2626262626262626262626262626262626262626262626262626262626262626262626262626");
        Uint8List extraInput = Codec.decodeHex(
            "0808080808080808080808080808080808080808080808080808080808080808");

        String secretNonce = Codec.encodeHex(KeyStore.calculateSecretNonce(
            rand, secretKey, publicKey, aggPubkey, message, extraInput,
            isDeterministic: false));
        expect(secretNonce.toUpperCase(),
            '3221975ACBDEA6820EABF02A02B7F27D3A8EF68EE42787B88CBEFD9AA06AF3632EE85B1A61D8EF31126D4663A00DD96E9D1D4959E72D70FE5EBB6E7696EBA66F024D4B6CD1361032CA9BD2AEB9D900AA4D45D9EAD80AC9423374C451A7254D0766');
      });
      test('Generate secret nonce (for scenario test)', () {
        Uint8List rand =
            Codec.decodeHex('3acc65ba29db1bdfb9d0af9c87525ee5df2205ee');
        Uint8List secretKey = Codec.decodeHex(
            '53758e643751e3c23fd15b1c08a80179c8a6a78fed51c6e5961e2ea9d381925a');
        Uint8List publicKey = Codec.decodeHex(
            "0231cd531693ac6f845e040afbad01fc13816869436d5bbaa0367abc3809b8848f");
        Uint8List aggPubkey = Codec.decodeHex(
            "5c6bc6c83ac710fa23c806e3744d90cbd54899f38cfdb2f6310e9d664f79b5b9");
        Uint8List message = Codec.decodeHex(
            "90e6bcf20fccc52e974ecd7e9fa2b7e7af5832d9b8285078095b8b5dfb8d045c");
        Uint8List extraInput = Codec.decodeHex("");

        String secretNonce = Codec.encodeHex(KeyStore.calculateSecretNonce(
            rand, secretKey, publicKey, aggPubkey, message, extraInput,
            isDeterministic: false));
        expect(secretNonce,
            'c931cdfc4c763bfec9404394cac7a5fe73d5a1c0f7c0ba106d24d7c8c4a141e63a74c366130dba7e587d9ca78a116751b9c98beb2388e2db53ae083e436e2e5b0231cd531693ac6f845e040afbad01fc13816869436d5bbaa0367abc3809b8848f');
      });
    });

    group('calculatePublicNonce', () {
      //Test vector from https://github.com/bitcoin/bips/blob/master/bip-0327/vectors/nonce_gen_vectors.json
      test('Generate public nonce (case 1)', () {
        Uint8List secretNonce = Codec.decodeHex(
            'B114E502BEAA4E301DD08A50264172C84E41650E6CB726B410C0694D59EFFB6495B5CAF28D045B973D63E3C99A44B807BDE375FD6CB39E46DC4A511708D0E9D2024D4B6CD1361032CA9BD2AEB9D900AA4D45D9EAD80AC9423374C451A7254D0766');

        String publicNonce =
            Codec.encodeHex(KeyStore.calculatePublicNonce(secretNonce));
        expect(publicNonce.toUpperCase(),
            '02F7BE7089E8376EB355272368766B17E88E7DB72047D05E56AA881EA52B3B35DF02C29C8046FDD0DED4C7E55869137200FBDBFE2EB654267B6D7013602CAED3115A');
      });
      test('Generate public nonce (case 2)', () {
        Uint8List secretNonce = Codec.decodeHex(
            'E862B068500320088138468D47E0E6F147E01B6024244AE45EAC40ACE5929B9F0789E051170B9E705D0B9EB49049A323BBBBB206D8E05C19F46C6228742AA7A9024D4B6CD1361032CA9BD2AEB9D900AA4D45D9EAD80AC9423374C451A7254D0766');

        String publicNonce =
            Codec.encodeHex(KeyStore.calculatePublicNonce(secretNonce));
        expect(publicNonce.toUpperCase(),
            '023034FA5E2679F01EE66E12225882A7A48CC66719B1B9D3B6C4DBD743EFEDA2C503F3FD6F01EB3A8E9CB315D73F1F3D287CAFBB44AB321153C6287F407600205109');
      });
      test('Generate public nonce (case 3)', () {
        Uint8List secretNonce = Codec.decodeHex(
            '3221975ACBDEA6820EABF02A02B7F27D3A8EF68EE42787B88CBEFD9AA06AF3632EE85B1A61D8EF31126D4663A00DD96E9D1D4959E72D70FE5EBB6E7696EBA66F024D4B6CD1361032CA9BD2AEB9D900AA4D45D9EAD80AC9423374C451A7254D0766');

        String publicNonce =
            Codec.encodeHex(KeyStore.calculatePublicNonce(secretNonce));
        expect(publicNonce.toUpperCase(),
            '02E5BBC21C69270F59BD634FCBFA281BE9D76601295345112C58954625BF23793A021307511C79F95D38ACACFF1B4DA98228B77E65AA216AD075E9673286EFB4EAF3');
      });
    });
    group('toString', () {
      test('Generate to String', () {
        expect(keyStore.toString(), contains('fingerprint'));
        expect(keyStore.toString(), contains('extendedPublicKey'));
      });
    });
    group('getSecretNonce', () {
      test(
          'getSecretNonce should return different values for same inputs (BIP-0327 security requirement)',
          () {
        KeyStore nonceKeyStore = KeyStore.fromSeed(seed, AddressType.p2tr);
        String aggPubkey =
            "5c6bc6c83ac710fa23c806e3744d90cbd54899f38cfdb2f6310e9d664f79b5b9";
        String message =
            "90e6bcf20fccc52e974ecd7e9fa2b7e7af5832d9b8285078095b8b5dfb8d045c";
        Uint8List nonce1 =
            nonceKeyStore.getSecretNonce(message, aggPubkey, 0, false);
        Uint8List nonce2 =
            nonceKeyStore.getSecretNonce(message, aggPubkey, 0, false);

        // BIP-0327: Nonce MUST be unique for each signing session
        // This test EXPECTS different nonces but will FAIL with current deterministic implementation
        expect(Codec.encodeHex(nonce1), isNot(equals(Codec.encodeHex(nonce2))),
            reason:
                'MuSig2 nonce should be nondeterministic to prevent key extraction attacks');
      });
    });

    group('getPublicNonce', () {
      test(
          'getPublicNonce should return different values for same inputs across different KeyStore instances',
          () {
        String sigHash =
            "90e6bcf20fccc52e974ecd7e9fa2b7e7af5832d9b8285078095b8b5dfb8d045c";
        String aggPubKey =
            "5c6bc6c83ac710fa23c806e3744d90cbd54899f38cfdb2f6310e9d664f79b5b9";
        int accountIndex = 0;
        bool isChange = false;

        KeyStore keyStore1 = KeyStore.fromSeed(seed, AddressType.p2tr);
        KeyStore keyStore2 = KeyStore.fromSeed(seed, AddressType.p2tr);

        String nonce1 = keyStore1.getPublicNonce(
            sigHash, aggPubKey, accountIndex, isChange);
        String nonce2 = keyStore2.getPublicNonce(
            sigHash, aggPubKey, accountIndex, isChange);

        // BIP-0327: Each signing session must use unique nonce
        // This test EXPECTS different nonces but will FAIL with current deterministic implementation
        expect(nonce1, isNot(equals(nonce2)),
            reason:
                'Different KeyStore instances should generate different nonces for security');
      });

      test(
          'multiple calls should return different nonces (replay attack protection)',
          () {
        String sigHash =
            "90e6bcf20fccc52e974ecd7e9fa2b7e7af5832d9b8285078095b8b5dfb8d045c";
        String aggPubKey =
            "5c6bc6c83ac710fa23c806e3744d90cbd54899f38cfdb2f6310e9d664f79b5b9";
        int accountIndex = 0;
        bool isChange = false;

        KeyStore keyStore = KeyStore.fromSeed(seed, AddressType.p2tr);

        String nonce1 =
            keyStore.getPublicNonce(sigHash, aggPubKey, accountIndex, isChange);
        String nonce2 =
            keyStore.getPublicNonce(sigHash, aggPubKey, accountIndex, isChange);
        String nonce3 =
            keyStore.getPublicNonce(sigHash, aggPubKey, accountIndex, isChange);

        // BIP-0327: Nonce reuse leads to private key extraction
        // This test EXPECTS different nonces but will FAIL with current deterministic implementation
        expect(nonce1, isNot(equals(nonce2)),
            reason:
                'Repeated getPublicNonce calls should generate different nonces');
        expect(nonce2, isNot(equals(nonce3)),
            reason:
                'Repeated getPublicNonce calls should generate different nonces');
      });
    });

    group('operator ==', () {
      test('Check equal', () {
        SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        SingleSignatureWallet wallet =
            SingleSignatureWallet.fromDescriptor(vault.descriptor);

        expect(wallet.keyStore == vault.keyStore, false);
        expect(wallet.keyStore.extendedPublicKey.serialize(),
            vault.keyStore.extendedPublicKey.serialize());
      });

      test('Check unequal', () {
        SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        expect(keyStore == vault.keyStore, false);
      });
    });
    group('hashCode', () {
      test('Equal object has same hashCode', () {
        final KeyStore a = KeyStore.fromExtendedPublicKey(
            keyStore.extendedPublicKey.serialize(), keyStore.masterFingerprint);
        final KeyStore b = KeyStore.fromExtendedPublicKey(
            keyStore.extendedPublicKey.serialize(), keyStore.masterFingerprint);
        expect(a == b, true);
        expect(a.hashCode, b.hashCode);
      });
    });

    group('getPublicKeyBytes', () {
      test('getPublicKeyBytes matches getPublicKey hex', () {
        final Uint8List pubBytes = keyStore.getPublicKeyBytes(0);
        expect(Codec.encodeHex(pubBytes), keyStore.getPublicKey(0));
      });
    });

    group('fromJson', () {
      test('fromJson restores serialized form', () {
        final KeyStore watchOnly = KeyStore.fromExtendedPublicKey(
            keyStore.extendedPublicKey.serialize(), keyStore.masterFingerprint);
        final String jsonText = watchOnly.toJson();
        final KeyStore restored = KeyStore.fromJson(jsonText);
        expect(restored.extendedPublicKey.serialize(),
            watchOnly.extendedPublicKey.serialize());
      });
    });

    group('toJson', () {
      test('serializes a watch-only key store', () {
        final watchOnly = KeyStore.fromExtendedPublicKey(
            keyStore.extendedPublicKey.serialize(), keyStore.masterFingerprint);
        final map = jsonDecode(watchOnly.toJson()) as Map<String, dynamic>;
        expect(map['fingerprint'], watchOnly.masterFingerprint);
        expect(
            map['extendedPublicKey'], watchOnly.extendedPublicKey.serialize());
        expect(map['seed'], isNull);
      });

      test('excludes private key material from a signing key store', () {
        final signing =
            KeyStore.fromSeed(MockFactory.getCommonSeed(), AddressType.p2wpkh);
        final jsonText = signing.toJson();
        final map = jsonDecode(jsonText) as Map<String, dynamic>;
        final hdWalletMap =
            jsonDecode(map['hdWallet'] as String) as Map<String, dynamic>;

        expect(map.containsKey('seed'), isFalse);
        expect(hdWalletMap.containsKey('privateKey'), isFalse);
        expect(jsonText, isNot(contains('machine crack daughter')));

        final restored = KeyStore.fromJson(jsonText);
        expect(restored.hasSeed, isFalse);
        expect(restored.hdWallet.isNeutered(), isTrue);
        expect(restored.extendedPublicKey.serialize(),
            signing.extendedPublicKey.serialize());
      });
    });

    group('wipeSeed', () {
      test('clears private wallets and preserves public derivation', () {
        final KeyStore mutable =
            KeyStore.fromSeed(MockFactory.getCommonSeed(), AddressType.p2wpkh);
        final HDWallet accountWallet = mutable.hdWallet;
        final HDWallet receiveWallet = mutable.getChildHdWallet(false);
        final HDWallet changeWallet = mutable.getChildHdWallet(true);
        final Uint8List accountPrivateKey = accountWallet.privateKey!;
        final Uint8List receivePrivateKey = receiveWallet.privateKey!;
        final Uint8List changePrivateKey = changeWallet.privateKey!;
        final String receivePublicKey = mutable.getPublicKey(0);

        expect(mutable.hasSeed, true);
        mutable.wipeSeed();

        expect(mutable.hasSeed, false);
        expect(accountPrivateKey, everyElement(0));
        expect(receivePrivateKey, everyElement(0));
        expect(changePrivateKey, everyElement(0));
        expect(accountWallet.isNeutered(), isTrue);
        expect(receiveWallet.isNeutered(), isTrue);
        expect(changeWallet.isNeutered(), isTrue);
        expect(mutable.hdWallet.isNeutered(), isTrue);
        expect(mutable.getChildHdWallet(false).isNeutered(), isTrue);
        expect(mutable.getChildHdWallet(true).isNeutered(), isTrue);
        expect(mutable.getPublicKey(0), receivePublicKey);
        expect(() => mutable.getPrivateKey(0), throwsException);
        expect(() => accountWallet.signEcdsa(Uint8List(32)), throwsStateError);

        final map = jsonDecode(mutable.toJson()) as Map<String, dynamic>;
        final hdWalletMap =
            jsonDecode(map['hdWallet'] as String) as Map<String, dynamic>;
        expect(map.containsKey('seed'), isFalse);
        expect(hdWalletMap.containsKey('privateKey'), isFalse);
      });
    });

    group('addPublicNonceToPsbt', () {
      test('Add public nonce to PSBT', () {
        TaprootVault vault = MockFactory.createP2trVaultOnlyKeys();
        KeyStore keyStore = vault.keyStoreList[0];
        Psbt psbt = Psbt.fromTransaction(
            Transaction.forSinglePayment(
                [MockFactory.getCommonUtxo(AddressType.p2tr)],
                vault.getAddress(1),
                '${vault.derivationPath}/1/1',
                15000,
                3,
                vault),
            vault);

        Psbt noncePsbt =
            Psbt.parse(keyStore.addPublicNonceToPsbt(psbt.serialize()));
        String aggregatedPublicNonce =
            noncePsbt.inputs[0].getAggregatedPublicNonce();
        expect(Codec.decodeHex(aggregatedPublicNonce), hasLength(66));
      });
    });
  });

  group('MuSigSessionContext', () {
    group('getMuSig2PublicNonce', () {
      Uint8List aggregatePublicKey(List<Uint8List> publicKeyList,
          {bool isSort = true, bool isXOnly = true}) {
        if (isSort) {
          publicKeyList.sort((a, b) {
            int len = a.length < b.length ? a.length : b.length;

            for (int i = 0; i < len; i++) {
              if (a[i] != b[i]) {
                return a[i].compareTo(b[i]);
              }
            }

            return a.length.compareTo(b.length);
          });
        }

        late Uint8List secondKey = Uint8List(0);
        for (Uint8List key in publicKeyList) {
          if (Codec.encodeHex(publicKeyList[0]) != Codec.encodeHex(key)) {
            secondKey = key;
            break;
          }
        }

        String concatenatedPublicKey =
            publicKeyList.map((e) => Codec.encodeHex(e)).join();

        Uint8List Q = publicKeyList[0];

        for (int i = 0; i < publicKeyList.length; i++) {
          Uint8List coefficient = Uint8List(0);
          if (Codec.encodeHex(publicKeyList[i]) == Codec.encodeHex(secondKey)) {
            coefficient = Uint8List.fromList(List<int>.generate(
                32,
                (i) => int.parse(
                    BigInt.one
                        .toRadixString(16)
                        .padLeft(64, '0')
                        .substring(i * 2, i * 2 + 2),
                    radix: 16)));
          } else {
            String data = Codec.encodeHex(Hash.taggedHash(
                    'KeyAgg list', Codec.decodeHex(concatenatedPublicKey))) +
                Codec.encodeHex(publicKeyList[i]);

            coefficient =
                Hash.taggedHash('KeyAgg coefficient', Codec.decodeHex(data));
          }

          if (i == 0) {
            Q = Ecc.pointMultiplyScalar(publicKeyList[i], coefficient, true)!;
          } else {
            Q = Ecc.pointCombine(
                Q,
                Ecc.pointMultiplyScalar(publicKeyList[i], coefficient, true)!,
                true)!;
          }
        }

        if (isXOnly) {
          return Q.sublist(1);
        } else {
          return Q;
        }
      }

      test('Generate session context', () {
        Uint8List message = Codec.decodeHex(
            '6701942fd0f38440a7c410a3fcf6a6e10bd76a4974c3b0a9553e60528c78a6b5');
        List<Uint8List> participantPublicKeys = [
          Codec.decodeHex(
              '0231cd531693ac6f845e040afbad01fc13816869436d5bbaa0367abc3809b8848f'),
          Codec.decodeHex(
              '0236df5f7ac13900bef3fa97c66110397344af522501630a7490cd88e91fff1e24'),
          Codec.decodeHex(
              '02e9ee267a4bd5d0df21cc649bdda375bb5510d173ed4127b15da93f0717b1f99d')
        ];
        Uint8List aggregatedPublicKey =
            aggregatePublicKey(participantPublicKeys, isXOnly: false);
        Uint8List aggregatedPubNonce = Codec.decodeHex(
            '03ddffdfd8f613ca697f313579e80adbf34564fac6ce5808b6d0dde9d09327c1b002cfa39d381c6366ebdd7019641dba6dd453f9d38f56d38b0d7e33b51cfbfe95ef');
        SessionContext sessionContext = SessionContext(participantPublicKeys,
            aggregatedPubNonce, aggregatedPublicKey, message,
            applyTaprootTweak: false);
        expect(Codec.encodeHex(Ecc.getEncoded(sessionContext.aggregateQ, true)),
            '0244c18be84322bd051743e9dac38d8a9472fc1e39d66ea3951da419747a4f96eb');
        expect(sessionContext.b.toString(),
            '42452304263695163620196203845095753431190306116738962141428713186034786858279');
        expect(sessionContext.R.x.toString(),
            '60143870298663942742991689092797257507829257715383491360440278844229307818615');
        expect(sessionContext.e.toString(),
            '75550762600552793952557687225983707197539317791023912703967559988774299150629');
      });
    });
  });
}
