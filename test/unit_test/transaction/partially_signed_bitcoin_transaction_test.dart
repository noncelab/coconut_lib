@Tags(['unit'])
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../mock_factory.dart';

void main() {
  group('Psbt', () {
    late Psbt unsignedPsbt;
    late Psbt signedPsbt;
    setUp(() {
      unsignedPsbt = MockFactory.createP2wpkhUnsignedPsbt();
      signedPsbt = MockFactory.createP2wpkhSignedPsbt();
    });
    group('fee', () {
      test('Get final fee', () {
        expect(signedPsbt.fee, 423);
      });
    });
    group('sendingAmount', () {
      test('Get sending amount except fee and change', () {
        expect(
            signedPsbt.sendingAmount(MockFactory.createP2wpkhVault()), 15000);
      });
    });
    group('addressType', () {
      test('Resolve address type from psbt input fields', () {
        expect(unsignedPsbt.addressType, AddressType.p2wpkh);
      });
    });

    group('wallet', () {
      test('identifies owned outputs after parsing', () {
        final wallet = MockFactory.createP2wpkhVault();

        final parsed = Psbt.parse(unsignedPsbt.serialize());

        expect(parsed.outputs[0].isOwnedBy(wallet), false);
        expect(parsed.outputs[1].isOwnedBy(wallet), true);
      });

      test('does not identify outputs owned by another wallet', () {
        final otherWallet =
            MockFactory.createP2wpkhVault(passphrase: 'another wallet');

        final parsed = Psbt.parse(unsignedPsbt.serialize());

        expect(parsed.outputs.every((output) => !output.isOwnedBy(otherWallet)),
            true);
      });

      test('identifies multisig and taproot owned outputs', () {
        final multisigPsbt = MockFactory.createP2wshUnsignedPsbt();
        final taprootPsbt = MockFactory.createP2trKeyPathSpendingUnsignedPsbt();

        final multisigWallet = MockFactory.createP2wshVault();
        final taprootWallet = MockFactory.createP2trKeyPathSpendingVault();

        expect(multisigPsbt.outputs[0].isOwnedBy(multisigWallet), false);
        expect(multisigPsbt.outputs[1].isOwnedBy(multisigWallet), true);
        expect(taprootPsbt.outputs[0].isOwnedBy(taprootWallet), false);
        expect(taprootPsbt.outputs[1].isOwnedBy(taprootWallet), true);
      });

      test('uses BIP-371 output derivations for taproot change', () {
        final taprootWallet = MockFactory.createP2trKeyPathSpendingVault();
        final taprootPsbt = MockFactory.createP2trKeyPathSpendingUnsignedPsbt();
        final Map<String, dynamic> outputMap =
            taprootPsbt.toKeyMap()['outputs'][1];

        expect(outputMap.keys.any((key) => key.startsWith('07')), true);
        expect(outputMap.keys.any((key) => key.startsWith('02')), false);
        expect(taprootPsbt.outputs[1].bip32Derivations, isEmpty);
        expect(taprootPsbt.outputs[1].tapBip32Derivations, hasLength(1));
        expect(taprootPsbt.outputs[1].tapBip32Derivations.single.publicKey,
            hasLength(64));
        expect(taprootPsbt.outputs[1].tapBip32Derivations.single.leafHashes,
            isEmpty);

        final reparsed = Psbt.parse(taprootPsbt.serialize());
        expect(reparsed.outputs[1].isChange(taprootWallet), true);
      });

      test('preserves taproot output leaf hashes for script policies', () {
        final taprootWallet = MockFactory.createP2trVaultWithPolicies();
        final transaction = Transaction.forSinglePayment(
            MockFactory.createTaprootUtxoList(count: 1),
            taprootWallet.getAddress(1),
            '${taprootWallet.derivationPath}/1/1',
            15000,
            3,
            taprootWallet);

        final psbt = Psbt.fromTransaction(transaction, taprootWallet);
        final reparsed = Psbt.parse(psbt.serialize());
        final derivations = reparsed.outputs[1].tapBip32Derivations;

        expect(derivations, hasLength(3));
        expect(
            derivations.where((derivation) =>
                derivation.leafHashes.length == 1 &&
                derivation.leafHashes.single.length == 64),
            hasLength(3));
        expect(reparsed.outputs[1].isChange(taprootWallet), true);
      });

      test('requires a wallet when checking ownership and change', () {
        final parsed = Psbt.parse(unsignedPsbt.serialize());
        final wallet = MockFactory.createP2wpkhVault();

        expect(parsed.outputs[1].isOwnedBy(wallet), true);
        expect(parsed.outputs[1].isChange(wallet), true);
      });
    });

    group('matchesVault', () {
      test('Check if psbt is for single signature vault', () {
        SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        expect(unsignedPsbt.matchesVault(vault), true);
        expect(
            unsignedPsbt
                .matchesVault(MockFactory.createP2wpkhVault(passphrase: 'Z')),
            false);
      });
      test('Check if psbt is for multisignature vault', () {
        MultisignatureVault vault = MockFactory.createP2wshVault();
        expect(MockFactory.createP2wshUnsignedPsbt().matchesVault(vault), true);
        final vault1 = MockFactory.createP2wpkhVault(passphrase: 'A');
        final vault2 = MockFactory.createP2wpkhVault(passphrase: 'B');
        final vault3 = MockFactory.createP2wpkhVault(passphrase: 'C');

        KeyStore keyStore1 =
            KeyStore.fromSeed(vault1.keyStore.seed, AddressType.p2wsh);
        KeyStore keyStore2 =
            KeyStore.fromSeed(vault2.keyStore.seed, AddressType.p2wsh);
        KeyStore keyStore3 =
            KeyStore.fromSeed(vault3.keyStore.seed, AddressType.p2wsh);

        MultisignatureVault targetVault1 = MultisignatureVault.fromKeyStoreList(
            [keyStore1, keyStore2, keyStore3], 3);
        MultisignatureVault targetVault2 =
            MultisignatureVault.fromKeyStoreList([keyStore1, keyStore2], 2);

        expect(MockFactory.createP2wshUnsignedPsbt().matchesVault(targetVault1),
            false);
        expect(MockFactory.createP2wshUnsignedPsbt().matchesVault(targetVault2),
            false);
      });
      test('Check if psbt is for taproot vault', () {
        KeyStore keyStore1 = KeyStore.fromSeed(
            Seed.fromMnemonic(
                utf8.encode(
                    'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
                passphrase: utf8.encode('A')),
            AddressType.p2tr);
        KeyStore keyStore2 = KeyStore.fromSeed(
            Seed.fromMnemonic(
                utf8.encode(
                    'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
                passphrase: utf8.encode('B')),
            AddressType.p2tr);
        TaprootVault childSingleVault =
            MockFactory.createBeneficiaryVault(passphrase: 'C');
        Policy policy1 = InheritancePolicy.fromDescriptorAndLocktime(
            childSingleVault.descriptor, 1767225600);
        Policy policy2 = InheritancePolicy.fromDescriptorAndLocktime(
            MockFactory.createBeneficiaryVault(passphrase: 'P2').descriptor,
            1767225600);
        Policy policy3 = InheritancePolicy.fromDescriptorAndLocktime(
            MockFactory.createBeneficiaryVault(passphrase: 'P3').descriptor,
            1767225600);
        TaprootVault vault = TaprootVault.fromKeyStoreList(
            [keyStore1, keyStore2], [policy1, policy2, policy3]);
        int addressIndex = 1;
        Utxo utxo = Utxo(
            '3a371051041b93e19c268a5080a2a98c01e4f281621d39791faeeff61e9208c0',
            1,
            21000,
            "m/86'/1'/0'/0/$addressIndex");

        Transaction tx = Transaction.forSinglePayment([utxo],
            MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vault);
        TaprootVault childVault =
            TaprootVault.fromCoordinatorBsms(vault.getCoordinatorBsms());
        childVault.bindSeedToBeneficiaryKeyStore(
            childSingleVault.keyStoreList[0].seed);
        tx.setPolicy(childVault.getSpendablePolicy());
        Psbt unsignedPsbt = Psbt.fromTransaction(tx, vault);
        expect(unsignedPsbt.matchesVault(vault), true);
        expect(unsignedPsbt.matchesVault(childVault), true);
        TaprootVault targetVault = TaprootVault.fromKeyStoreList(
            [keyStore1, keyStore2], [policy1, policy2]);
        expect(unsignedPsbt.matchesVault(targetVault), false);
      });

      test('matches only the single signature vault that owns the key', () {
        final SingleSignatureVault vaultA = MockFactory.createP2wpkhVault();
        final SingleSignatureVault vaultB =
            MockFactory.createP2wpkhVault(passphrase: 'vaultB');

        final Transaction txForA = Transaction.forSinglePayment(
            MockFactory.createUtxoList(count: 1),
            vaultA.getAddress(1),
            '${vaultA.derivationPath}/1/1',
            15000,
            3,
            vaultA);
        final Psbt psbtForVaultA = Psbt.fromTransaction(txForA, vaultA);

        expect(psbtForVaultA.matchesVault(vaultA), isTrue);
        expect(psbtForVaultA.matchesVault(vaultB), isFalse);
      });

      test(
          'distinguishes multisig vaults with same keys but different required signers',
          () {
        final SingleSignatureVault signerA =
            MockFactory.createP2wpkhVault(passphrase: 'A');
        final SingleSignatureVault signerB =
            MockFactory.createP2wpkhVault(passphrase: 'B');
        final SingleSignatureVault signerC =
            MockFactory.createP2wpkhVault(passphrase: 'C');

        final KeyStore keyStoreA =
            KeyStore.fromSeed(signerA.keyStore.seed, AddressType.p2wsh);
        final KeyStore keyStoreB =
            KeyStore.fromSeed(signerB.keyStore.seed, AddressType.p2wsh);
        final KeyStore keyStoreC =
            KeyStore.fromSeed(signerC.keyStore.seed, AddressType.p2wsh);
        final List<KeyStore> keyStores = [keyStoreA, keyStoreB, keyStoreC];

        final MultisignatureVault vault2Of3 =
            MultisignatureVault.fromKeyStoreList(keyStores, 2);
        final MultisignatureVault vault3Of3 =
            MultisignatureVault.fromKeyStoreList(keyStores, 3);

        final Transaction txFor2Of3 = Transaction.forSinglePayment(
            MockFactory.createUtxoList(
                count: 1, derivationPath: "${vault2Of3.derivationPath}/0/0"),
            vault2Of3.getAddress(1),
            '${vault2Of3.derivationPath}/1/1',
            15000,
            3,
            vault2Of3);
        final Psbt psbtFor2Of3 = Psbt.fromTransaction(txFor2Of3, vault2Of3);

        final Transaction txFor3Of3 = Transaction.forSinglePayment(
            MockFactory.createUtxoList(
                count: 1, derivationPath: "${vault3Of3.derivationPath}/0/0"),
            vault3Of3.getAddress(1),
            '${vault3Of3.derivationPath}/1/1',
            15000,
            3,
            vault3Of3);
        final Psbt psbtFor3Of3 = Psbt.fromTransaction(txFor3Of3, vault3Of3);

        expect(psbtFor2Of3.matchesVault(vault2Of3), isTrue);
        expect(psbtFor2Of3.matchesVault(vault3Of3), isFalse);
        expect(psbtFor3Of3.matchesVault(vault2Of3), isFalse);
        expect(psbtFor3Of3.matchesVault(vault3Of3), isTrue);
      });

      test('matches only the exact taproot vault parent and child key set', () {
        final KeyStore parentA1 = KeyStore.fromSeed(
            Seed.fromMnemonic(
                utf8.encode(
                    'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
                passphrase: utf8.encode('parentA1')),
            AddressType.p2tr);
        final KeyStore parentA2 = KeyStore.fromSeed(
            Seed.fromMnemonic(
                utf8.encode(
                    'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
                passphrase: utf8.encode('parentA2')),
            AddressType.p2tr);
        final TaprootVault childA =
            MockFactory.createBeneficiaryVault(passphrase: 'childA');
        final Policy childPolicyA = InheritancePolicy.fromDescriptorAndLocktime(
            childA.descriptor, 1767225600);
        final TaprootVault vaultA =
            TaprootVault.fromKeyStoreList([parentA1, parentA2], [childPolicyA]);
        final TaprootVault vaultB =
            TaprootVault.fromKeyStoreList([parentA1], [childPolicyA]);

        const int addressIndex = 0;
        final Utxo utxo = Utxo(
            '0b5b43a8a09f1021bac4f4357c2808043b409231b42fc0143050ac37668a984b',
            0,
            21000,
            "m/86'/1'/0'/0/$addressIndex");
        final Transaction txForA = Transaction.forSinglePayment([utxo],
            MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vaultA);
        final Psbt psbtForVaultA = Psbt.fromTransaction(txForA, vaultA);
        final Transaction txForB = Transaction.forSinglePayment([utxo],
            MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vaultB);
        final Psbt psbtForVaultB = Psbt.fromTransaction(txForB, vaultB);

        expect(psbtForVaultA.matchesVault(vaultA), isTrue);
        expect(psbtForVaultA.matchesVault(vaultB), isFalse);
        expect(psbtForVaultB.matchesVault(vaultA), isFalse);
        expect(psbtForVaultB.matchesVault(vaultB), isTrue);
      });

      test('only beneficiary locktime diff of taproot wallets', () {
        final KeyStore parentA1 = KeyStore.fromSeed(
            Seed.fromMnemonic(
                utf8.encode(
                    'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
                passphrase: utf8.encode('parentA1')),
            AddressType.p2tr);
        final KeyStore parentA2 = KeyStore.fromSeed(
            Seed.fromMnemonic(
                utf8.encode(
                    'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
                passphrase: utf8.encode('parentA2')),
            AddressType.p2tr);
        final TaprootVault childA =
            MockFactory.createBeneficiaryVault(passphrase: 'childA');
        final Policy childPolicyA = InheritancePolicy.fromDescriptorAndLocktime(
            childA.descriptor, 1767225600);
        final Policy childPolicyB = InheritancePolicy.fromDescriptorAndLocktime(
            childA.descriptor, 1767225601);
        final TaprootVault vaultA =
            TaprootVault.fromKeyStoreList([parentA1, parentA2], [childPolicyA]);
        final TaprootVault vaultB =
            TaprootVault.fromKeyStoreList([parentA1, parentA2], [childPolicyB]);

        const int addressIndex = 0;
        final Utxo utxo = Utxo(
            '0b5b43a8a09f1021bac4f4357c2808043b409231b42fc0143050ac37668a984b',
            0,
            21000,
            "m/86'/1'/0'/0/$addressIndex");
        final Transaction txForA = Transaction.forSinglePayment([utxo],
            MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vaultA);
        final Transaction txForB = Transaction.forSinglePayment([utxo],
            MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vaultB);

        final Psbt psbtForVaultA = Psbt.fromTransaction(txForA, vaultA);
        final Psbt psbtForVaultB = Psbt.fromTransaction(txForB, vaultB);

        expect(psbtForVaultA.matchesVault(vaultA), isTrue);
        expect(psbtForVaultA.matchesVault(vaultB), isFalse);
        expect(psbtForVaultB.matchesVault(vaultA), isFalse);
        expect(psbtForVaultB.matchesVault(vaultB), isTrue);
      });
    });
    group('serialize', () {
      test('Get base64 psbt', () {
        final String unsignedSerialized = unsignedPsbt.serialize();
        final String signedSerialized = signedPsbt.serialize();
        expect(Psbt.parse(unsignedSerialized).serialize(), unsignedSerialized);
        expect(Psbt.parse(signedSerialized).serialize(), signedSerialized);
      });
    });
    group('toKeyMap', () {
      test('Get key map', () {
        Map<String, dynamic> psbtMap = unsignedPsbt.toKeyMap();
        String input0 =
            '{"01": "a086010000000000160014b54542413855bca0894e855b7858cd07bca87b80", "03": "01000000", "060246c18ea7c5624b87e5f65a60842c9a22b27ae7e3630a95abeb35455259761824": "98C7D7745400008001000080000000800000000000000000"}';
        expect(psbtMap['inputs'][0], jsonDecode(input0));
      });
    });

    group('Psbt.fromTransaction', () {
      test('Generate psbt from transaction object (single sig)', () {
        SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        Transaction tx = Transaction.forSinglePayment(
            MockFactory.createUtxoList(count: 1),
            vault.getAddress(1),
            '${vault.derivationPath}/1/1',
            15000,
            3,
            vault);
        Psbt psbt = Psbt.fromTransaction(tx, vault);
        expect(psbt.serialize(), unsignedPsbt.serialize());
      });

      test('Generate psbt from transaction object (multisig)', () {
        MultisignatureVault vault = MockFactory.createP2wshVault();
        Transaction tx = Transaction.forSinglePayment(
            MockFactory.createUtxoList(
                count: 1, derivationPath: '${vault.derivationPath}/0/0'),
            vault.getAddress(1),
            '${vault.derivationPath}/1/1',
            15000,
            3,
            vault);
        Psbt psbt = Psbt.fromTransaction(tx, vault);
        final String serialized = psbt.serialize();
        expect(Psbt.parse(serialized).serialize(), serialized);
      });

      test('rejects a transaction input and UTXO count mismatch', () {
        final SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        final Transaction tx = Transaction.forSinglePayment(
            MockFactory.createUtxoList(count: 1),
            vault.getAddress(1),
            '${vault.derivationPath}/1/1',
            15000,
            3,
            vault);
        tx.utxoList.add(tx.utxoList.single);

        expect(
            () => Psbt.fromTransaction(tx, vault),
            throwsA(isA<PsbtException>().having((error) => error.code, 'code',
                CoconutErrorCode.transactionInputMismatch)));
      });

      test('rejects a UTXO with a different output index', () {
        final SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        final Transaction tx = Transaction.forSinglePayment(
            MockFactory.createUtxoList(count: 1),
            vault.getAddress(1),
            '${vault.derivationPath}/1/1',
            15000,
            3,
            vault);
        final Utxo original = tx.utxoList.single;
        tx.utxoList[0] = Utxo(original.transactionHash, original.index + 1,
            original.amount, original.derivationPath);

        expect(
            () => Psbt.fromTransaction(tx, vault),
            throwsA(isA<PsbtException>()
                .having((error) => error.code, 'code',
                    CoconutErrorCode.utxoMismatch)
                .having((error) => error.inputIndex, 'inputIndex', 0)));
      });

      test('rejects duplicate input outpoints', () {
        final SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        final Utxo utxo = MockFactory.createUtxoList(count: 1).single;
        final Transaction tx = Transaction.forSinglePayment(
            [utxo, utxo],
            vault.getAddress(1),
            '${vault.derivationPath}/1/1',
            15000,
            3,
            vault);

        expect(
            () => Psbt.fromTransaction(tx, vault),
            throwsA(isA<PsbtException>()
                .having((error) => error.code, 'code',
                    CoconutErrorCode.duplicateUtxo)
                .having((error) => error.inputIndex, 'inputIndex', 1)));
      });
    });
    group('Psbt.parse', () {
      test('Reject malformed PSBT lengths and trailing data', () {
        expect(() => Psbt.parse(base64Encode([0x70, 0x73])),
            throwsFormatException);
        expect(
            () =>
                Psbt.parse(base64Encode([0x70, 0x73, 0x62, 0x74, 0xff, 0xfd])),
            throwsFormatException);
        expect(
            () => Psbt.parse(
                base64Encode([0x70, 0x73, 0x62, 0x74, 0xff, 0x02, 0x00])),
            throwsFormatException);

        final bytes = base64Decode(unsignedPsbt.serialize());
        expect(() => Psbt.parse(base64Encode([...bytes, 0x01])),
            throwsFormatException);
      });

      test('Generate psbt from base64 1', () {
        Psbt psbt = Psbt.parse(unsignedPsbt.serialize());
        expect(psbt.serialize(), unsignedPsbt.serialize());
      });
      test('Generate psbt from base64 2', () {
        String genPsbt =
            'cHNidP8BAHECAAAAAWUg7t4pxeA0A2pGGYAUkmjiY/7YpbjlJ+rYhiEj45BrAQAAAAD+////Ak4EAAAAAAAAFgAUc/eqTbaEfqsnxZIU9u1yVGJ+feDBJgAAAAAAABYAFI/e1ckmFCiom0RpZFOnYL+LGj00AAAAACIBAoVTlNWX9SGtm5cFiwwI8Wa3/ghN1Rcn5sFq/HiYIljOEHdHvlRUAACAAQAAgAAAAIAAAQDeAgAAAAABAbOIzj00k4UxHYxukCF+IGpm0wrLGRNpFFd5wnAKSj2FAAAAAAD9////AiPnFBIAAAAAFgAUydEYuAChkfMw6AXd43kGvY9wOo8ELQAAAAAAABYAFMsyXCmsHZ+cVqt3x/ZZ9qMEp70CAkcwRAIgbDLOfc52CI/bgcNruhEK5K3Tjs6/964Dw2MIKToN+XkCID943pnpCRlb8KgUllCu1TPrq2HJi+TWrbiGRj3VUOP/ASECx4cRBpF4/xfXe+U6es7busrE2sopPkLGH3MDNiEI/SJlBSsAAQEfBC0AAAAAAAAWABTLMlwprB2fnFard8f2WfajBKe9AiIGAzsEkr9cCgIipVzeoEzcAisXUREjga5umXAxmz1rFh25GMzw5sZUAACAAQAAgAAAAIAAAAAAAAAAAAAAAA==';
        Psbt psbt = Psbt.parse(genPsbt);
        // expect(psbt.derivationPathList[0].path, "m/84'/1'/0'");
        expect(psbt.unsignedTransaction!.transactionHash,
            'b968c83476792ac3ead52749f61957ce926dca5d9749fa6eed5440ebe3e44290');
        expect(psbt.inputs[0].witnessUtxo?.amount.toString(), '11524');
      });

      test('Generate psbt from base64 3', () {
        String psbtString =
            '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';
        Psbt psbt = Psbt.parse(psbtString);
        expect(psbt.serialize().replaceAll("AA==", ""), psbtString);
      });

      test('Generate psbt from base64 4', () {
        String psbtString =
            'cHNidP8BAKACAAAAAqsJSaCMWvfEm4IS9Bfi8Vqz9cM9zxU4IagTn4d6W3vkAAAAAAD+////qwlJoIxa98SbghL0F+LxWrP1wz3PFTghqBOfh3pbe+QBAAAAAP7///8CYDvqCwAAAAAZdqkUdopAu9dAy+gdmI5x3ipNXHE5ax2IrI4kAAAAAAAAGXapFG9GILVT+glechue4O/p+gOcykWXiKwAAAAAAAEHakcwRAIgR1lmF5fAGwNrJZKJSGhiGDR9iYZLcZ4ff89X0eURZYcCIFMJ6r9Wqk2Ikf/REf3xM286KdqGbX+EhtdVRs7tr5MZASEDXNxh/HupccC1AaZGoqg7ECy0OIEhfKaC3Ibi1z+ogpIAAQEgAOH1BQAAAAAXqRQ1RebjO4MsRwUPJNPuuTycA5SLx4cBBBYAFIXRNTfy4mVAWjTbr6nj3aAfuCMIAAAA';
        Psbt psbt = Psbt.parse(psbtString);
        expect(psbt.serialize().replaceAll("AA==", ""), psbtString);
      });

      test('Generate psbt from base64 5', () {
        String psbtString =
            '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';
        Psbt psbt = Psbt.parse(psbtString);
        expect(psbt.unsignedTransaction!.transactionHash,
            "71ae48a404ce3ad731981532b3dbbde539f27ffc042c0f830576b50478cc16ea");
        expect(psbt.outputs[0].bip32Derivations.single.publicKey,
            "0246c18ea7c5624b87e5f65a60842c9a22b27ae7e3630a95abeb35455259761824");
      });
      test('Generate psbt from base64 6', () {
        String psbtString =
            'cHNidP8BAIkCAAAAAfNQVSxA8DG4n4i3H1s1j2RJpIkpZ3X5bZoBEPlWLTo5AAAAAAD/////Apg6AAAAAAAAIgAgJRhRa9P3QWARqg+7N8PqjjBht5hkC0zTebkRkzx3NeqtSQEAAAAAACIAIP9vANiW3Z4tVtCAsOsqO62JSFbOgRbyRCv++o/yEPZRAAAAAE8BAldUgwQ591iwgAAAAorbsW1x14HiywcBbOJN5QGKT7zr//rK5XGdiTaeopVFA1w0v9PEyzuK+SuMrYm59D0AC1yhH4Q2Mz2kFBuolXvfFJYUnjQwAACAAQAAgAAAAIACAACATwECV1SDBHIub6uAAAAChfZG32EzkK5e6q/8nJq2Q7j/4YTVHvILSa2OfRCAhbcCqEd4vSwUNu7sajcyrNDWG6bn4HpZAOwF1GUqAWjy3ogUNgkjyTAAAIABAACAAAAAgAIAAIBPAQJXVIMEpLtogYAAAAKqj/e/lMHOWC7quWCPi8I+tUguT3HLE0WdYAYXJWj2cwMiRP7BirY0IFk3TaIrbc7bFb342BEK3RLjNKcXVFm2rhSbyeZbMAAAgAEAAIAAAACAAgAAgAABASughgEAAAAAACIAIGqUPLeTUPZ9rqI0uitCmxnaYzZTtT17oSpLlIvvo5duIgYC1kgcHp6tP4ZQjsXUtRUImuQFBfZCkB4HiCQYTpENM2MYlhSeNFQAAIABAACAAAAAgAAAAAAAAAAAIgYChpECvtMyJwff6+rwb54PibXRM+SO5IG81iTfwfobGIAYNgkjyVQAAIABAACAAAAAgAAAAAAAAAAAIgYCgQbltUSeC3jn4GxkNfckuXl9sJJu07pZsB1uPe6P10sYm8nmW1QAAIABAACAAAAAgAAAAAAAAAAAAQVpUiECgQbltUSeC3jn4GxkNfckuXl9sJJu07pZsB1uPe6P10shAoaRAr7TMicH3+vq8G+eD4m10TPkjuSBvNYk38H6GxiAIQLWSBwenq0/hlCOxdS1FQia5AUF9kKQHgeIJBhOkQ0zY1OuAAEDBJg6AAABBCMiACAlGFFr0/dBYBGqD7s3w+qOMGG3mGQLTNN5uRGTPHc16gABAwStSQEAAQQjIgAg/28A2Jbdni1W0ICw6yo7rYlIVs6BFvJEK/76j/IQ9lEiAgOh36B2evQihVn9BDRQgjZT1y9wJWpBNT+OhvfvWvhIcxyWFJ40MAAAgAEAAIAAAACAAgAAgAEAAAABAAAAIgIDs94XcehAh+/pkSmEfdnxKPW0L6Ve4kjh48jGlJk3uzgcNgkjyTAAAIABAACAAAAAgAIAAIABAAAAAQAAACICAuNIkH306xQBwBgDsP1AsAMxrwSNnpKwO2WjH4tzlPqtHJvJ5lswAACAAQAAgAAAAIACAACAAQAAAAEAAAAAAA==';
        Psbt psbt = Psbt.parse(psbtString);
        expect(psbt.extendedPublicKeyList.length, 3);
      });

      test('Generate psbt from base64 7', () {
        String psbtString =
            'cHNidP8BAFICAAAAAWUg7t4pxeA0A2pGGYAUkmjiY/7YpbjlJ+rYhiEj45BrAQAAAAABAAAAAfgqAAAAAAAAFgAUc/eqTbaEfqsnxZIU9u1yVGJ+feAAAAAAIgEChVOU1Zf1Ia2blwWLDAjxZrf+CE3VFyfmwWr8eJgiWM4Qd0e+VFQAAIABAACAAAAAgAABAN4CAAAAAAEBs4jOPTSThTEdjG6QIX4gambTCssZE2kUV3nCcApKPYUAAAAAAP3///8CI+cUEgAAAAAWABTJ0Ri4AKGR8zDoBd3jeQa9j3A6jwQtAAAAAAAAFgAUyzJcKawdn5xWq3fH9ln2owSnvQICRzBEAiBsMs59znYIj9uBw2u6EQrkrdOOzr/3rgPDYwgpOg35eQIgP3jemekJGVvwqBSWUK7VM+urYcmL5NatuIZGPdVQ4/8BIQLHhxEGkXj/F9d75Tp6ztu6ysTayik+QsYfcwM2IQj9ImUFKwABAR8ELQAAAAAAABYAFMsyXCmsHZ+cVqt3x/ZZ9qMEp70CIgYDOwSSv1wKAiKlXN6gTNwCKxdRESOBrm6ZcDGbPWsWHbkYzPDmxlQAAIABAACAAAAAgAAAAAAAAAAAIgIDOwSSv1wKAiKlXN6gTNwCKxdRESOBrm6ZcDGbPWsWHblIMEUCIQDzaaPhvftio/+HX6YLyYNDJt6teJok/8svr19IYoJA6AIgFMwhYwmo3tKWWXz9JoBShynApV5Dgm2K99Fg1Fvj34YBAAEDBPgqAAABBBcWABRz96pNtoR+qyfFkhT27XJUYn594CICApaPYnyq0NL/g79f7tMP2059h/m9ZVfoDSuJjgdjz4f6GMzw5sZUAACAAQAAgAAAAIAAAAAAAQAAAAAA';
        Psbt psbt = Psbt.parse(psbtString);
        expect(psbt.inputs[0].partialSig![0].signature,
            '3045022100f369a3e1bdfb62a3ff875fa60bc9834326dead789a24ffcb2faf5f48628240e8022014cc216309a8ded296597cfd2680528729c0a55e43826d8af7d160d45be3df8601');
        expect(psbt.inputs[0].partialSig![0].publicKey,
            '033b0492bf5c0a0222a55cdea04cdc022b1751112381ae6e9970319b3d6b161db9');
      });
    });

    group('Psbt.fromMap', () {
      test('Generate psbt from key map', () {
        Map<String, dynamic> keyMap = signedPsbt.toKeyMap();
        Psbt psbt = Psbt.fromMap(keyMap);
        expect(psbt.serialize(), signedPsbt.serialize());
      });
    });
    group('addPartialSig', () {
      test('Add signature to psbt', () {
        unsignedPsbt.inputs[0].addPartialSig(
            '3045022100de494cd0a05a5621d8303a024130fc43550af2ec456de026174c542dfb1706e5022037f358ddba9025abc70d19693014304158eda80877e00f4b9cea86d18d4fad9801',
            '0246c18ea7c5624b87e5f65a60842c9a22b27ae7e3630a95abeb35455259761824');

        expect(signedPsbt.serialize(), unsignedPsbt.serialize());
        unsignedPsbt = MockFactory.createP2wshUnsignedPsbt();
      });
    });
    group('getKeyType', () {
      test('Get key type for psbt (input)', () {
        expect(Psbt.getKeyType(Psbt.inputKeyType, 'WITNESS_UTXO'), '01');
      });
      test('Get key type for psbt (global)', () {
        expect(Psbt.getKeyType(Psbt.globalKeyType, 'XPUB'), '01');
      });
      test('Get key type for psbt (output)', () {
        expect(Psbt.getKeyType(Psbt.outputKeyType, 'AMOUNT'), '03');
      });
    });
    group('getAggregatedPublicNonce', () {
      test('Get aggregated public nonce from input index', () {
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
        expect(noncePsbt.getAggregatedPublicNonce(0),
            noncePsbt.inputs[0].getAggregatedPublicNonce());
      });
    });
    group('getSignedTransaction', () {
      test('Get signed transaction from psbt', () {
        final String signedTxHex =
            signedPsbt.getSignedTransaction(AddressType.p2wpkh).serialize();
        expect(Transaction.parse(signedTxHex).serialize(), signedTxHex);
      });

      test('Taproot defaults to SIGHASH_DEFAULT without a PSBT sighash field',
          () {
        final Psbt psbt = MockFactory.createP2trKeyPathSpendingUnsignedPsbt();
        final Map<String, dynamic> inputMap = psbt.toKeyMap()['inputs'][0];

        expect(inputMap.containsKey('03'), isFalse);
        expect(Psbt.parse(psbt.serialize()).inputs[0].sighashType, isNull);
      });

      test('Taproot SIGHASH_ALL is parsed, signed and finalized consistently',
          () {
        final TaprootVault vault = MockFactory.createP2trKeyPathSpendingVault();
        final Psbt unsigned =
            MockFactory.createP2trKeyPathSpendingUnsignedPsbt();
        unsigned.toKeyMap()['inputs'][0]['03'] = '01000000';
        final Psbt withSighashAll = Psbt.fromMap(unsigned.toKeyMap());

        final Psbt signed =
            Psbt.parse(vault.addSignatureToPsbt(withSighashAll.serialize()));
        expect(signed.inputs[0].sighashType, 0x01);
        expect(signed.inputs[0].tapKeySig, hasLength(130));
        expect(signed.inputs[0].tapKeySig, endsWith('01'));

        final Transaction transaction =
            signed.getSignedTransaction(AddressType.p2tr);
        expect(transaction.inputs[0].witnessList.single, endsWith('01'));
      });

      test('rejects unsupported Taproot sighash types before signing', () {
        final TaprootVault vault = MockFactory.createP2trKeyPathSpendingVault();
        final Psbt unsigned =
            MockFactory.createP2trKeyPathSpendingUnsignedPsbt();
        unsigned.toKeyMap()['inputs'][0]['03'] = '02000000';
        final Psbt unsupported = Psbt.fromMap(unsigned.toKeyMap());

        expect(() => vault.addSignatureToPsbt(unsupported.serialize()),
            throwsUnsupportedError);
      });
    });

    group('validateSignature', () {
      test('Validate signature for psbt (segwit)', () {
        expect(
            unsignedPsbt.validateSignature(
                0,
                '3045022100de494cd0a05a5621d8303a024130fc43550af2ec456de026174c542dfb1706e5022037f358ddba9025abc70d19693014304158eda80877e00f4b9cea86d18d4fad9801',
                '0246c18ea7c5624b87e5f65a60842c9a22b27ae7e3630a95abeb35455259761824'),
            true);
      });
      test('Validate signature for psbt (taproot)', () {
        final Psbt signedPsbt =
            MockFactory.createP2trKeyPathSpendingSignedPsbt();
        final PsbtInput input = signedPsbt.inputs[0];
        expect(input.tapKeySig, isNotNull);

        final Uint8List outputKey =
            input.witnessUtxo!.scriptPubKey.commands[1] as Uint8List;
        final String outputKeyHex = Codec.encodeHex(outputKey);
        expect(signedPsbt.validateSignature(0, input.tapKeySig!, outputKeyHex),
            true);
      });
    });

    group('isSigned', () {
      group('Check if psbt is signed', () {
        test('Check if psbt is signed (segwit)', () {
          SingleSignatureVault vault = MockFactory.createP2wpkhVault();
          Psbt unsignedPsbt = MockFactory.createP2wpkhUnsignedPsbt();
          Psbt signedPsbt = MockFactory.createP2wpkhSignedPsbt();

          expect(unsignedPsbt.isSigned(vault.keyStore), false);
          expect(signedPsbt.isSigned(vault.keyStore), true);
        });
        test('Check if psbt is signed (taproot)', () {
          TaprootVault vault = MockFactory.createP2trKeyPathSpendingVault();
          Psbt unsignedPsbt =
              MockFactory.createP2trKeyPathSpendingUnsignedPsbt();
          Psbt signedPsbt = MockFactory.createP2trKeyPathSpendingSignedPsbt();

          expect(
              unsignedPsbt.isSigned(vault.keyStoreList[0],
                  isKeyPathSpending: true),
              false);
          expect(
              signedPsbt.isSigned(vault.keyStoreList[0],
                  isKeyPathSpending: true),
              true);
        });
      });
    });
  });
  group('PsbtInput', () {
    late PsbtInput input;
    late PsbtInput multisigInput;

    setUpAll(() {
      input = MockFactory.createP2wpkhUnsignedPsbt().inputs[0];
      multisigInput = MockFactory.createP2wshUnsignedPsbt().inputs[0];
    });

    group('witnessUtxo', () {
      test('Get witness utxo', () {
        expect(input.witnessUtxo!.serialize(),
            'a086010000000000160014b54542413855bca0894e855b7858cd07bca87b80');
      });
    });
    group('derivationPathList', () {
      test('Get derivation path list', () {
        expect(input.bip32Derivation![0].path, "m/84'/1'/0'/0/0");
        expect(multisigInput.bip32Derivation![0].path, "m/48'/1'/0'/2'/0/0");
      });
    });
    group('requiredSignature', () {
      test('Get number of required signature', () {
        expect(multisigInput.requiredSignature, 2);
      });
    });
    group('totalSigner', () {
      test('Get number of total signer', () {
        expect(multisigInput.totalSigner, 3);
      });
    });
    group('addPartialSig', () {
      test('Add signature into the psbt input', () {
        expect(
            () => multisigInput.addPartialSig(
                '3045022100d5bf91f97ad7ee474c320f821744a59d10bc225aa6709ee70f7776b53f28515702203d15ca1b7c7ebd44a7991868b99168ce9963e0dccc48ea47cce91a317a5cdae401',
                '02d6481c1e9ead3f86508ec5d4b515089ae40505f642901e078824184e910d3363'),
            returnsNormally);
      });
    });

    group('signatureList', () {
      test('reflects added signatures', () {
        final PsbtInput mutableInput =
            MockFactory.createP2wpkhUnsignedPsbt().inputs[0];
        expect(mutableInput.signatureList, isEmpty);
        mutableInput.addPartialSig(
            '304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c092001',
            mutableInput.derivationPathList.first.publicKey);
        expect(mutableInput.signatureList.length, 1);
      });
    });

    group('signedCount', () {
      test('reflects added signatures', () {
        final PsbtInput mutableInput =
            MockFactory.createP2wpkhUnsignedPsbt().inputs[0];
        expect(mutableInput.signedCount, 0);
        mutableInput.addPartialSig(
            '304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c092001',
            mutableInput.derivationPathList.first.publicKey);
        expect(mutableInput.signedCount, 1);
      });
    });

    group('addTapKeySig', () {
      test('updates tapKeySig', () {
        final PsbtInput tapInput =
            MockFactory.createP2trKeyPathSpendingUnsignedPsbt().inputs[0];
        tapInput.addTapKeySig('aa' * 64);
        expect(tapInput.tapKeySig, isNotNull);
      });
    });

    group('addTapScriptSig', () {
      test('updates tapScriptSig', () {
        final PsbtInput tapInput =
            MockFactory.createP2trKeyPathSpendingUnsignedPsbt().inputs[0];
        tapInput.addTapScriptSig('bb' * 64, '02${'11' * 32}');
        expect(tapInput.tapScriptSig, isNotNull);
      });
    });

    group('addMuSig2PubNonce', () {
      test('updates muSig2PubNonces', () {
        final PsbtInput tapInput =
            MockFactory.createP2trKeyPathSpendingUnsignedPsbt().inputs[0];
        tapInput.addMuSig2PubNonce(
            '02${'22' * 32}', '03${'33' * 32}', '44' * 32, '55' * 66);
        expect(tapInput.muSig2PubNonces, isNotNull);
      });
    });

    group('addMuSig2PartialSig', () {
      test('updates muSig2PartialSigs', () {
        final PsbtInput tapInput =
            MockFactory.createP2trKeyPathSpendingUnsignedPsbt().inputs[0];
        tapInput.addMuSig2PartialSig(
            '66' * 64, '02${'22' * 32}', '03${'33' * 32}', '44' * 32);
        expect(tapInput.muSig2PartialSigs, isNotNull);
      });
    });
    group('aggregatePublicNonce', () {
      //Test vector from : https://github.com/bitcoin/bips/blob/master/bip-0327/vectors/nonce_agg_vectors.json
      test('Get aggregated public nonce (case 1)', () {
        List<Uint8List> nonces = [
          Codec.decodeHex(
              "020151C80F435648DF67A22B749CD798CE54E0321D034B92B709B567D60A42E66603BA47FBC1834437B3212E89A84D8425E7BF12E0245D98262268EBDCB385D50641"),
          Codec.decodeHex(
              "03FF406FFD8ADB9CD29877E4985014F66A59F6CD01C0E88CAA8E5F3166B1F676A60248C264CDD57D3C24D79990B0F865674EB62A0F9018277A95011B41BFC193B833")
        ];

        expect(
            Codec.encodeHex(PsbtInput.aggregatePublicNonce(nonces))
                .toUpperCase(),
            '035FE1873B4F2967F52FEA4A06AD5A8ECCBE9D0FD73068012C894E2E87CCB5804B024725377345BDE0E9C33AF3C43C0A29A9249F2F2956FA8CFEB55C8573D0262DC8');
      });

      test('Get aggregated public nonce (case 2)', () {
        List<Uint8List> nonces = [
          Codec.decodeHex(
              "020151C80F435648DF67A22B749CD798CE54E0321D034B92B709B567D60A42E6660279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798"),
          Codec.decodeHex(
              "03FF406FFD8ADB9CD29877E4985014F66A59F6CD01C0E88CAA8E5F3166B1F676A60379BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798")
        ];

        expect(
            Codec.encodeHex(PsbtInput.aggregatePublicNonce(nonces))
                .toUpperCase(),
            '035FE1873B4F2967F52FEA4A06AD5A8ECCBE9D0FD73068012C894E2E87CCB5804B000000000000000000000000000000000000000000000000000000000000000000');
      });
    });
  });
  group('PsbtOutput', () {
    late PsbtOutput output;
    late PsbtOutput multisigOutput;
    late PsbtOutput multisigChangeOutput;
    late PsbtOutput parsedPsbtOutput;
    late SingleSignatureVault wallet;
    late MultisignatureVault multisigWallet;

    setUpAll(() {
      wallet = MockFactory.createP2wpkhVault();
      multisigWallet = MockFactory.createP2wshVault();
      output = MockFactory.createP2wpkhUnsignedPsbt().outputs[0];
      final Psbt multisigPsbt = MockFactory.createP2wshUnsignedPsbt();
      multisigOutput = multisigPsbt.outputs[0];
      multisigChangeOutput = multisigPsbt.outputs[1];
      String psbtString =
          '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';
      parsedPsbtOutput = Psbt.parse(psbtString).outputs[0];
    });
    group('derivationPath', () {
      test('Get derivation path from psbt output', () {
        expect(
            parsedPsbtOutput.bip32Derivations.single.path, "m/84'/1'/0'/0/0");
      });

      test('preserves every multisig output derivation path', () {
        expect(multisigChangeOutput.bip32Derivations, hasLength(3));
        expect(
            multisigChangeOutput.bip32Derivations
                .map((derivation) => derivation.path)
                .toSet(),
            {"m/48'/1'/0'/2'/1/1"});
      });
    });
    group('amount', () {
      test('Get amount of psbt output', () {
        expect(multisigOutput.outAmount, 15000);
      });
    });
    group('outAddress', () {
      test('Get address of psbt output', () {
        expect(output.outAddress, 'tb1qcjx6kazryh26wzpr2p66w2s0f7nv29n07fx05a');
      });
    });
    group('isOwned', () {
      test('is true only for an output owned by the supplied wallet', () {
        expect(output.isOwnedBy(wallet), false);
        expect(multisigOutput.isOwnedBy(multisigWallet), false);
        expect(multisigChangeOutput.isOwnedBy(multisigWallet), true);
      });
    });
    group('isChange', () {
      test('is true only for an owned output on the change branch', () {
        expect(output.isChange(wallet), false);
        expect(multisigOutput.isChange(multisigWallet), false);
        expect(multisigChangeOutput.isChange(multisigWallet), true);
      });

      test('rejects a foreign address with forged change derivations', () {
        final forgedOutput = PsbtOutput(multisigChangeOutput.bip32Derivations,
            multisigOutput.outAmount, multisigOutput.outScript);

        expect(forgedOutput.isOwnedBy(multisigWallet), false);
        expect(forgedOutput.isChange(multisigWallet), false);
      });
    });
  });
  group('DerivationPath', () {
    late PsbtOutput parsedPsbtOutput;

    setUpAll(() {
      String psbtString =
          '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';
      parsedPsbtOutput = Psbt.parse(psbtString).outputs[0];
    });
    group('publicKey', () {
      test('Get public key of bip32 derivation path', () {
        expect(parsedPsbtOutput.bip32Derivations.single.publicKey,
            "0246c18ea7c5624b87e5f65a60842c9a22b27ae7e3630a95abeb35455259761824");
      });
    });
    group('masterFingerprint', () {
      test('Get master fingerprint of bip32 derivation path', () {
        expect(parsedPsbtOutput.bip32Derivations.single.masterFingerprint,
            "98C7D774");
      });
    });
    group('path', () {
      test('Get derivation path', () {
        expect(
            parsedPsbtOutput.bip32Derivations.single.path, "m/84'/1'/0'/0/0");
      });
    });
  });
}
