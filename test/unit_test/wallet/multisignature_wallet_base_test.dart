@Tags(['unit'])
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('MultisignatureWalletBase', () {
    late MultisignatureVault vault;
    setUpAll(() {
      vault = WalletFixture.p2wshVault();
    });
    group('totalSigner', () {
      test('Get total signer of vault', () {
        expect(vault.totalSigner, 3);
      });
    });
    group('requiredSignature', () {
      test('Get required signature of vault', () {
        expect(vault.requiredSignature, 2);
      });
    });
    group('keyStoreList', () {
      test('Get key store list from vault', () {
        expect(vault.keyStoreList, isA<List<KeyStore>>());
        expect(vault.keyStoreList.length, 3);
      });

      test('watch-only wallet rejects seed-bearing key stores', () {
        expect(
            () => MultisignatureWallet(
                2, AddressType.p2wsh, vault.derivationPath, vault.keyStoreList),
            throwsArgumentError);
      });
    });
    group('getAddress', () {
      test('Get address from vault', () {
        expect(vault.getAddress(0),
            'tb1qd22redun2rm8mt4zxjazks5mr8dxxdjnk57hhgf2fw2ghmarjahqm9g672');
        expect(vault.getAddress(0, isChange: true),
            'tb1qqpte5pxtdrpaw8xqxc2t3j3n3c0v02trla9zwfvnw59nguj8h9lqqtsqn2');
      });
    });

    group('getAddressWithDerivationPath', () {
      test('get address from vault with derivation path', () {
        expect(vault.getAddressWithDerivationPath("m/48'/1'/0'/2'/10/0"),
            'tb1qd22redun2rm8mt4zxjazks5mr8dxxdjnk57hhgf2fw2ghmarjahqm9g672');
        expect(vault.getAddressWithDerivationPath("m/48'/1'/0'/2'/10/1"),
            'tb1qy5v9z67n7aqkqyd2p7an0sl23ccxrducvs95e5mehygex0rhxh4qth92w0');
        expect(vault.getAddressWithDerivationPath("m/48'/1'/0'/2'/10/5"),
            'tb1qq0q7qav557ea92qszuytkyh33ly8elz0whcuwsycux59pzqnyulsc5vskx');
      });

      test('rejects paths outside the wallet account', () {
        expect(() => vault.getAddressWithDerivationPath("m/48'/1'/1'/2'/0/0"),
            throwsException);
        expect(() => vault.getAddressWithDerivationPath("m/48'/1'/0'/2'/x/0"),
            throwsException);
      });
    });
    group('getKeyOriginExpression', () {
      test('contains every signer fingerprint', () {
        final expression = vault.getKeyOriginExpression();
        for (final keyStore in vault.keyStoreList) {
          expect(expression, contains(keyStore.masterFingerprint));
        }
      });
    });
    group('getCoordinatorBsms', () {
      test('Get coordinator bsms from vault', () {
        expect(vault.getCoordinatorBsms().hashCode, 1032617779);
      });
    });
    group('getWitnessScript', () {
      test('Get witness script of vault', () {
        expect(
            vault.getWitnessScript("m/48'/1'/0'/2'/10/1").hashCode, 669698738);
      });

      test('rejects address types without witness scripts', () {
        final legacyVault = MultisignatureVault(
            2, AddressType.p2sh, 0, "m/45'/1'/0'", vault.keyStoreList);
        expect(() => legacyVault.getWitnessScript("m/45'/0/0"),
            throwsUnsupportedError);
      });
    });
    group('hasPublicKeyInPsbt', () {
      test('Check the vault can sign', () {
        MultisignatureVault otherVault =
            WalletFixture.p2wshVault(kind: TestWalletKind.random);
        Psbt psbt = PsbtFixture.p2wshUnsigned();
        expect(otherVault.hasPublicKeyInPsbt(psbt.serialize()), false);
        expect(vault.hasPublicKeyInPsbt(psbt.serialize()), true);
      });
    });
    group('addSignatureToPsbt', () {
      test('Sign to PSBT', () {
        Psbt unsignedPsbt = PsbtFixture.p2wshUnsigned();
        String signedPsbtText =
            vault.addSignatureToPsbt(unsignedPsbt.serialize());
        expect(signedPsbtText.hashCode, 141350171);

        Psbt signedPsbt = Psbt.parse(signedPsbtText);

        for (PsbtInput input in signedPsbt.inputs) {
          expect(input.requiredSignature, input.signedCount);
        }
      });

      test('throws when psbt address type mismatches', () {
        final psbt = PsbtFixture.p2wpkhUnsigned();
        expect(
            () => vault.addSignatureToPsbt(psbt.serialize()), throwsException);
      });

      test('rejects a weaker multisig policy before signing', () {
        final Psbt psbt = PsbtFixture.p2wshUnsigned();
        final MultisignatureScript weakerScript = MultisignatureScript.forP2wsh(
            1,
            vault.totalSigner,
            psbt.inputs[1].witnessScript!.getPublicKeys());
        psbt.toKeyMap()['inputs'][1]['05'] = weakerScript.rawSerialize();
        final Psbt forgedPsbt = Psbt.parse(psbt.serialize());

        expect(forgedPsbt.matchesVault(vault), isFalse);
        expect(() => vault.addSignatureToPsbt(forgedPsbt.serialize()),
            throwsA(isA<Exception>()));
        expect(
            forgedPsbt.inputs.every((input) => input.signedCount == 0), isTrue);
      });

      test('rejects derivation metadata that does not match its public key',
          () {
        final Psbt psbt = PsbtFixture.p2wshUnsigned();
        final Map<String, dynamic> inputMap = psbt.toKeyMap()['inputs'][0];
        final String derivationKey =
            inputMap.keys.firstWhere((key) => key.startsWith('06'));
        final String derivationValue = inputMap[derivationKey];
        inputMap[derivationKey] =
            '${derivationValue.substring(0, derivationValue.length - 8)}e7030000';
        final Psbt forgedPsbt = Psbt.parse(psbt.serialize());

        expect(forgedPsbt.matchesVault(vault), isFalse);
        expect(() => vault.addSignatureToPsbt(forgedPsbt.serialize()),
            throwsA(isA<Exception>()));
      });
    });

    group('MultisignatureWalletBase', () {
      test('rejects single-signature address types', () {
        expect(
            () => MultisignatureVault(
                2, AddressType.p2wpkh, 0, "m/84'/1'/0'", vault.keyStoreList),
            throwsArgumentError);
      });

      test('rejects malformed derivation paths', () {
        expect(
            () => MultisignatureVault(
                2, AddressType.p2wsh, 0, 'invalid', vault.keyStoreList),
            throwsException);
      });

      test('rejects derivation paths for another network', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        try {
          expect(
              () => MultisignatureVault(2, AddressType.p2wsh, 0,
                  "m/48'/1'/0'/2'", vault.keyStoreList),
              throwsException);
        } finally {
          NetworkType.setNetworkType(NetworkType.testnet);
        }
      });
    });

    group('getAggregatedPublicKey', () {
      test('Get aggregatedPublicKey', () {});
    });
  });
}
