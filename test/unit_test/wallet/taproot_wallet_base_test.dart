@Tags(['unit'])
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../mock_factory.dart';

void main() {
  group('TaprootWalletBase', () {
    late TaprootVault vault;
    setUp(() {
      vault = MockFactory.createP2trVaultWithPolicies();
    });

    Uint8List concat(Uint8List a, Uint8List b) {
      final out = Uint8List(a.length + b.length);
      out.setRange(0, a.length, a);
      out.setRange(a.length, a.length + b.length, b);
      return out;
    }

    int lexicographicCompare(Uint8List a, Uint8List b) {
      final minLen = a.length < b.length ? a.length : b.length;
      for (int i = 0; i < minLen; i++) {
        if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
      }
      if (a.length == b.length) return 0;
      return a.length < b.length ? -1 : 1;
    }

    Uint8List tapBranchHash(Uint8List a, Uint8List b) {
      final compare = lexicographicCompare(a, b);
      final first = compare <= 0 ? a : b;
      final second = compare <= 0 ? b : a;
      return Hash.taggedHash('TapBranch', concat(first, second));
    }

    Uint8List reconstructMerkleRootFromControlBlock({
      required Uint8List leafHash,
      required Uint8List controlBlockBytes,
    }) {
      // control block = 1 byte (0xc0|parityBit) + 32 bytes (internal key xonly) + N*32 bytes (merkle path)
      if (controlBlockBytes.length < 1 + 32) {
        throw ArgumentError('Invalid control block length');
      }
      final merklePathBytes = controlBlockBytes.sublist(1 + 32);
      if (merklePathBytes.length % 32 != 0) {
        throw ArgumentError('Invalid merkle path length in control block');
      }

      Uint8List current = leafHash;
      for (int i = 0; i < merklePathBytes.length; i += 32) {
        final sibling =
            merklePathBytes.sublist(i, i + 32); // tap sibling at each level
        current = tapBranchHash(current, sibling);
      }
      return current;
    }

    group('keyStoreList', () {
      test('returns parent signing key stores', () {
        expect(vault.keyStoreList, isNotEmpty);
      });
    });

    group('isVault', () {
      test('distinguishes a vault from a watch-only wallet', () {
        final wallet = TaprootWallet.fromDescriptor(vault.descriptor);
        expect(vault.isVault, isTrue);
        expect(wallet.isVault, isFalse);
      });
    });

    group('policyList', () {
      test('returns the descriptor policies', () {
        expect(vault.policyList, isNotEmpty);
      });
    });

    group('getInternalKey', () {
      test('returns an x-only internal key', () {
        expect(vault.getInternalKey(0), hasLength(32));
      });
    });

    group('getOutputKey', () {
      test('returns the tweaked x-only output key', () {
        expect(vault.getOutputKey(0), hasLength(32));
        expect(Codec.encodeHex(vault.getOutputKey(0)),
            isNot(Codec.encodeHex(vault.getInternalKey(0))));
      });
    });

    group('getKeyOriginExpression', () {
      test('contains each parent key fingerprint', () {
        final expression = vault.getKeyOriginExpression();
        for (final keyStore in vault.keyStoreList) {
          expect(expression, contains(keyStore.masterFingerprint));
        }
      });
    });

    group('getAddress', () {
      test('returns a valid taproot address', () {
        NetworkType.setNetworkType(NetworkType.regtest);
        expect(vault.getAddress(0),
            'bcrt1pcjtpvtuclk3kznj4kh6rpkucmceascus8ec85994z7c84m9cf96quyw3k2');
      });

      test('supports change addresses (isChange=true)', () {
        NetworkType.setNetworkType(NetworkType.testnet);
        expect(vault.getAddress(0, isChange: true),
            'tb1pcvjfhkempg7u78d2e67j5ns8x406vh9j3weqxrretdy4gx300pgqdryp9g');
      });
    });

    group('getAddressWithDerivationPath', () {
      test('validates derivation path', () {
        NetworkType.setNetworkType(NetworkType.testnet);
        expect(vault.getAddressWithDerivationPath("m/86'/1'/0'/0/0"),
            "tb1pcjtpvtuclk3kznj4kh6rpkucmceascus8ec85994z7c84m9cf96q3ayhrs");
        expect(vault.getAddressWithDerivationPath("m/86'/1'/0'/0/1"),
            "tb1p0jtzj2ukjewq7x20kl8g6zq3aph5sq3v2lf6nnfzqu9n9ft4u8pq38wz9z");
      });

      test('throws on mismatch path', () {
        expect(() => vault.getAddressWithDerivationPath("m/84'/1'/0'/0/0"),
            throwsException);
        expect(() => vault.getAddressWithDerivationPath("m/86'/1'/0x/0/0"),
            throwsException);
      });
    });

    group('hasPublicKeyInPsbt', () {
      test('returns true when psbt contains a key from one of keyStores', () {
        Utxo utxo = Utxo(
            '4518033c0c22e2fafd5779d5f5c4e4df4849730581d5d93658de18444b1080d6',
            1,
            21000,
            "m/86'/1'/0'/0/0");

        Transaction tx = Transaction.forSinglePayment([utxo],
            MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vault);

        // Build PSBT using the wallet that owns the UTXO (parentVault),
        // then sign via beneficiaryVault using script path.
        Psbt psbt = Psbt.fromTransaction(tx, vault);
        expect(vault.hasPublicKeyInPsbt(psbt.serialize()), true);

        SingleSignatureVault targetVault = SingleSignatureVault.random();
        expect(targetVault.hasPublicKeyInPsbt(psbt.serialize()), false);
      });

      test('returns true when psbt contains a key from policy list', () {
        TaprootVault childVault =
            MockFactory.createBeneficiaryVault(passphrase: 'C');
        TaprootVault beneficiaryVault =
            TaprootVault.fromDescriptor(vault.descriptor);
        beneficiaryVault
            .bindSeedToBeneficiaryKeyStore(childVault.keyStoreList[0].seed);
        Utxo utxo = Utxo(
            '4518033c0c22e2fafd5779d5f5c4e4df4849730581d5d93658de18444b1080d6',
            1,
            21000,
            "m/86'/1'/0'/0/0");
        Transaction tx = Transaction.forSinglePayment([utxo],
            MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vault);
        tx.setPolicy(beneficiaryVault.getSpendablePolicy());

        Psbt psbt = Psbt.fromTransaction(tx, beneficiaryVault);
        expect(beneficiaryVault.hasPublicKeyInPsbt(psbt.serialize()), true);
      });

      test('throws on address type mismatch', () {
        final p2wpkh = MockFactory.createP2wpkhUnsignedPsbt();
        expect(() => vault.hasPublicKeyInPsbt(p2wpkh.serialize()),
            throwsException);
      });
    });

    group('addSignatureToPsbt', () {
      test('adds signatures when seeds exist', () {
        Utxo utxo = Utxo(
            '4518033c0c22e2fafd5779d5f5c4e4df4849730581d5d93658de18444b1080d6',
            1,
            21000,
            "m/86'/1'/0'/0/0");
        Transaction tx = Transaction.forSinglePayment([utxo],
            MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vault);
        Psbt psbt = Psbt.fromTransaction(tx, vault);
        Psbt noncePsbt = Psbt.parse(vault.addPublicNonce(psbt.serialize()));
        Psbt signedPsbt =
            Psbt.parse(vault.addSignatureToPsbt(noncePsbt.serialize()));
        Transaction signedTx =
            signedPsbt.getSignedTransaction(vault.addressType);
        expect(
            signedTx.validateSchnorr(0, [
              TransactionOutput.forPayment(utxo.amount, vault.getAddress(0))
            ]),
            true);
      });
      test('adds signatures for script path', () {
        TaprootVault childVault =
            MockFactory.createBeneficiaryVault(passphrase: 'C');
        TaprootVault beneficiaryVault =
            TaprootVault.fromDescriptor(vault.descriptor);
        beneficiaryVault
            .bindSeedToBeneficiaryKeyStore(childVault.keyStoreList[0].seed);
        Utxo utxo = Utxo(
            '4518033c0c22e2fafd5779d5f5c4e4df4849730581d5d93658de18444b1080d6',
            1,
            21000,
            "m/86'/1'/0'/0/0");
        Transaction tx = Transaction.forSinglePayment(
            [utxo],
            MockFactory.reveiveAddress,
            "m/86'/1'/0'/1/0",
            20000,
            1,
            beneficiaryVault);
        tx.setPolicy(beneficiaryVault.getSpendablePolicy());
        Psbt psbt = Psbt.fromTransaction(tx, beneficiaryVault);
        Psbt noncePsbt =
            Psbt.parse(beneficiaryVault.addPublicNonce(psbt.serialize()));
        Psbt signedPsbt = Psbt.parse(
            beneficiaryVault.addSignatureToPsbt(noncePsbt.serialize()));
        Transaction signedTx =
            signedPsbt.getSignedTransaction(beneficiaryVault.addressType);
        expect(
            signedTx.validateSpend([
              TransactionOutput.forPayment(
                  utxo.amount, beneficiaryVault.getAddress(0))
            ]),
            true);
      });

      test('rejects a forged internal key in a later input', () {
        final List<Utxo> utxos = MockFactory.createTaprootUtxoList(count: 2);
        final Transaction tx = Transaction.forSinglePayment(utxos,
            MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 40000, 1, vault);
        final Psbt psbt = Psbt.fromTransaction(tx, vault);
        psbt.toKeyMap()['inputs'][1]['17'] = List.filled(32, '00').join();
        final Psbt forgedPsbt = Psbt.parse(psbt.serialize());

        expect(forgedPsbt.matchesVault(vault), isFalse);
        expect(
            () => forgedPsbt.validateTaprootPolicy(vault),
            throwsA(isA<PsbtException>()
                .having(
                    (error) => error.code, 'code', PsbtErrorCode.policyMismatch)
                .having((error) => error.inputIndex, 'inputIndex', 1)));
        expect(() => vault.addPublicNonce(forgedPsbt.serialize()),
            throwsException);
      });

      test('rejects a forged MuSig2 aggregated public key', () {
        final Utxo utxo = MockFactory.createTaprootUtxoList(count: 1).single;
        final Transaction tx = Transaction.forSinglePayment([utxo],
            MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vault);
        final Psbt psbt = Psbt.fromTransaction(tx, vault);
        final Map<String, dynamic> inputMap = psbt.toKeyMap()['inputs'][0];
        final String aggregateKey =
            inputMap.keys.firstWhere((key) => key.startsWith('1a'));
        final String participants = inputMap.remove(aggregateKey);
        inputMap['1a${participants.substring(0, 66)}'] = participants;
        final Psbt forgedPsbt = Psbt.parse(psbt.serialize());

        expect(forgedPsbt.matchesVault(vault), isFalse);
        expect(
            () => forgedPsbt.validateTaprootPolicy(vault),
            throwsA(isA<PsbtException>()
                .having(
                    (error) => error.code, 'code', PsbtErrorCode.signerMismatch)
                .having((error) => error.inputIndex, 'inputIndex', 0)));
      });

      test('rejects a forged script-path control block', () {
        final TaprootVault childVault =
            MockFactory.createBeneficiaryVault(passphrase: 'C');
        final TaprootVault beneficiaryVault =
            TaprootVault.fromDescriptor(vault.descriptor);
        beneficiaryVault
            .bindSeedToBeneficiaryKeyStore(childVault.keyStoreList[0].seed);
        final Utxo utxo = MockFactory.createTaprootUtxoList(count: 1).single;
        final Transaction tx = Transaction.forSinglePayment(
            [utxo],
            MockFactory.reveiveAddress,
            "m/86'/1'/0'/1/0",
            20000,
            1,
            beneficiaryVault);
        tx.setPolicy(beneficiaryVault.getSpendablePolicy());
        final Psbt psbt = Psbt.fromTransaction(tx, beneficiaryVault);
        final Map<String, dynamic> inputMap = psbt.toKeyMap()['inputs'][0];
        final String leafKey =
            inputMap.keys.firstWhere((key) => key.startsWith('15'));
        final String leafValue = inputMap.remove(leafKey);
        final String forgedControlBlock =
            '${leafKey.substring(2, leafKey.length - 2)}00';
        inputMap['15$forgedControlBlock'] = leafValue;
        final Psbt forgedPsbt = Psbt.parse(psbt.serialize());

        expect(forgedPsbt.matchesVault(beneficiaryVault), isFalse);
        expect(
            () => forgedPsbt.validateTaprootPolicy(beneficiaryVault),
            throwsA(isA<PsbtException>()
                .having(
                    (error) => error.code, 'code', PsbtErrorCode.policyMismatch)
                .having((error) => error.inputIndex, 'inputIndex', 0)));
      });
    });

    group('getCoordinatorBsms', () {
      test('returns non-empty coordinator payload', () {
        final bsms = vault.getCoordinatorBsms();
        expect(bsms.isNotEmpty, true);
      });
    });

    group('getAggregatedPublicKey', () {
      test('returns 32-byte x-only aggregated key', () {
        //0331cd531693ac6f845e040afbad01fc13816869436d5bbaa0367abc3809b8848f
        //0336df5f7ac13900bef3fa97c66110397344af522501630a7490cd88e91fff1e24
        expect(Codec.encodeHex(vault.getAggregatedPublicKey(0, isXOnly: true)),
            'ca86cf1e3ca9f06623db7c9e84ad1f1e6c5bf5eea7b107cd39031b84be94be1e');
      });
    });

    group('getMerkleRoot', () {
      test('returns 32-byte merkle root', () {
        expect(Codec.encodeHex(vault.getMerkleRoot(0)),
            'c0c3a5701c72559e142572600c7ac00cacdaaeaf23c5c82cac38ebf99e23c8e8');
      });
    });

    group('getControlBlock', () {
      test('throws when policy list is empty', () {
        final emptyPolicyVault = MockFactory.createP2trKeyPathSpendingVault();
        expect(() => emptyPolicyVault.getControlBlock(0, 0), throwsStateError);
      });

      test('throws when policy index is out of range', () {
        expect(() => vault.getControlBlock(-1, 0), throwsRangeError);
        expect(() => vault.getControlBlock(vault.policyList.length, 0),
            throwsRangeError);
      });

      test('reconstructs merkle root and validates parity (policyIndex=0)', () {
        final int addressIndex = 0;
        final bool isChange = false;
        final int policyIndex = 0;

        final String controlBlockHex = vault
            .getControlBlock(policyIndex, addressIndex, isChange: isChange);
        final Uint8List controlBlockBytes = Codec.decodeHex(controlBlockHex);

        // control block: 1 byte prefix + 32 bytes internal key + 32 bytes * path length
        expect(controlBlockBytes.length, greaterThan(1 + 32));
        expect((controlBlockBytes.length - (1 + 32)) % 32, 0,
            reason: 'merkle path part must be 32-byte aligned');

        final int controlByte = controlBlockBytes[0];
        final Uint8List internalKeyXOnly = controlBlockBytes.sublist(1, 33);

        final Uint8List expectedInternalKeyXOnly =
            vault.getInternalKey(addressIndex, isChange: isChange);
        expect(Codec.encodeHex(internalKeyXOnly),
            Codec.encodeHex(expectedInternalKeyXOnly));

        final List<Uint8List> leafHashes = vault.policyList
            .map((policy) =>
                policy.getTapleafHash(addressIndex, isChange: isChange))
            .toList();
        final Uint8List leafHash = leafHashes[policyIndex];

        final Uint8List merkleRootFromControl =
            reconstructMerkleRootFromControlBlock(
                leafHash: leafHash, controlBlockBytes: controlBlockBytes);
        final Uint8List expectedMerkleRoot =
            vault.getMerkleRoot(addressIndex, isChange: isChange);

        expect(Codec.encodeHex(merkleRootFromControl),
            Codec.encodeHex(expectedMerkleRoot));

        final Uint8List tweak = Hash.hashTapTweak(
            'TapTweak', expectedInternalKeyXOnly, expectedMerkleRoot);
        final Uint8List outputKey =
            Ecc.pointAddScalar(expectedInternalKeyXOnly, tweak, true)!;
        final int parityBitExpected = outputKey[0] == 0x03 ? 1 : 0;
        final int controlByteExpected = 0xc0 | parityBitExpected;
        expect(controlByte, controlByteExpected);
      });

      test('reconstructs merkle root and validates parity (policyIndex=2)', () {
        final int addressIndex = 0;
        final bool isChange = false;
        final int policyIndex = 2;

        final String controlBlockHex = vault
            .getControlBlock(policyIndex, addressIndex, isChange: isChange);
        final Uint8List controlBlockBytes = Codec.decodeHex(controlBlockHex);

        final Uint8List internalKeyXOnly = controlBlockBytes.sublist(1, 33);
        final Uint8List expectedInternalKeyXOnly =
            vault.getInternalKey(addressIndex, isChange: isChange);
        expect(Codec.encodeHex(internalKeyXOnly),
            Codec.encodeHex(expectedInternalKeyXOnly));

        final List<Uint8List> leafHashes = vault.policyList
            .map((policy) =>
                policy.getTapleafHash(addressIndex, isChange: isChange))
            .toList();

        final Uint8List merkleRootFromControl =
            reconstructMerkleRootFromControlBlock(
                leafHash: leafHashes[policyIndex],
                controlBlockBytes: controlBlockBytes);
        final Uint8List expectedMerkleRoot =
            vault.getMerkleRoot(addressIndex, isChange: isChange);
        expect(Codec.encodeHex(merkleRootFromControl),
            Codec.encodeHex(expectedMerkleRoot));

        final int controlByte = controlBlockBytes[0];
        final Uint8List tweak = Hash.hashTapTweak(
            'TapTweak', expectedInternalKeyXOnly, expectedMerkleRoot);
        final Uint8List outputKey =
            Ecc.pointAddScalar(expectedInternalKeyXOnly, tweak, true)!;
        final int parityBitExpected = outputKey[0] == 0x03 ? 1 : 0;
        final int controlByteExpected = 0xc0 | parityBitExpected;
        expect(controlByte, controlByteExpected);
      });
    });
  });
}
