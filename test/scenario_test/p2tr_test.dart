// @Tags(['scenario'])
import 'dart:convert';
import 'dart:typed_data';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../mock_factory.dart';

void main() {
  group('P2TR Test', () {
    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
    });

    bool validateKeyPath(String prevTx, String currTx, int inputIndex) {
      final Transaction funding = Transaction.parse(prevTx);
      final Transaction spending = Transaction.parse(currTx);

      if (funding.transactionHash.toLowerCase() !=
          spending.inputs[inputIndex].transactionHash.toLowerCase()) {
        return false;
      }

      final TransactionOutput prevOut =
          funding.outputs[spending.inputs[inputIndex].index];

      if (prevOut.scriptPubKey.isP2tr() == false) {
        return false;
      }

      if (spending.inputs[inputIndex].witnessList.length != 1) {
        return false;
      }

      final Uint8List outputKeyXOnly =
          Uint8List.fromList((prevOut.scriptPubKey.commands[1] as Uint8List));

      final Uint8List message =
          Codec.decodeHex(spending.getTaprootSigHash(inputIndex, [prevOut]));
      final Uint8List signature =
          Codec.decodeHex(spending.inputs[inputIndex].witnessList[0]);

      return Ecc.verifySchnorr(message, outputKeyXOnly, signature);
    }

    bool validateScriptPath(String prevTx, String currTx, int inputIndex) {
      final Transaction funding = Transaction.parse(prevTx);
      final Transaction spending = Transaction.parse(currTx);

      if (funding.transactionHash.toLowerCase() !=
          spending.inputs[inputIndex].transactionHash.toLowerCase()) {
        return false;
      }

      final TransactionOutput prevOut =
          funding.outputs[spending.inputs[inputIndex].index];

      if (prevOut.scriptPubKey.isP2tr() == false) {
        return false;
      }

      // Script path spend witness: [sig, tapscript, control_block]
      if (spending.inputs[inputIndex].witnessList.length != 3) {
        return false;
      }

      final Uint8List outputKeyXOnly =
          Uint8List.fromList((prevOut.scriptPubKey.commands[1] as Uint8List));

      final Uint8List signature =
          Codec.decodeHex(spending.inputs[inputIndex].witnessList[0]);
      final String tapscriptHex = spending.inputs[inputIndex].witnessList[1];
      final Uint8List controlBlockBytes =
          Codec.decodeHex(spending.inputs[inputIndex].witnessList[2]);

      if (controlBlockBytes.length < 33 ||
          (controlBlockBytes.length - 33) % 32 != 0) {
        return false;
      }

      // Control byte contains leaf version (even bits) and parity bit (lsb).
      final int controlByte = controlBlockBytes[0];
      final int leafVersion = controlByte & 0xfe;

      // Compute TapLeaf hash from raw tapscript bytes.
      final Uint8List scriptBytes = Codec.decodeHex(tapscriptHex);
      final Uint8List scriptLen =
          Codec.encodeVariableInteger(scriptBytes.length);
      final Uint8List tapleafHash = Hash.taggedHash('TapLeaf',
          Uint8List.fromList([leafVersion, ...scriptLen, ...scriptBytes]));

      // Verify control block commits to the spent output key.
      final Uint8List internalKeyXOnly = controlBlockBytes.sublist(1, 33);
      Uint8List merkleRoot = tapleafHash;
      for (int i = 33; i < controlBlockBytes.length; i += 32) {
        final Uint8List sibling = controlBlockBytes.sublist(i, i + 32);
        // TapBranch uses lexicographic sorting
        final int cmp = () {
          for (int j = 0; j < 32; j++) {
            if (merkleRoot[j] != sibling[j]) {
              return merkleRoot[j] < sibling[j] ? -1 : 1;
            }
          }
          return 0;
        }();
        final Uint8List first = cmp <= 0 ? merkleRoot : sibling;
        final Uint8List second = cmp <= 0 ? sibling : merkleRoot;
        merkleRoot = Hash.taggedHash(
            'TapBranch', Uint8List.fromList([...first, ...second]));
      }
      final Uint8List tweak =
          Hash.hashTapTweak('TapTweak', internalKeyXOnly, merkleRoot);
      Uint8List expectedOutputKey =
          Ecc.pointAddScalar(internalKeyXOnly, tweak, true)!;
      if (expectedOutputKey[0] == 0x03) {
        expectedOutputKey = Ecc.pointNegate(expectedOutputKey)!;
      }
      if (Codec.encodeHex(expectedOutputKey.sublist(1)) !=
          Codec.encodeHex(outputKeyXOnly)) {
        return false;
      }

      // For tapscript, sighash must include tapleafHash, keyVersion=0, codesep=0xffffffff.
      final Uint8List message = Codec.decodeHex(spending.getTaprootSigHash(
        inputIndex,
        [prevOut],
        isTapscript: true,
        tapleafHash: tapleafHash,
        keyVersion: 0,
        codesepPos: 0xffffffff,
      ));

      // Extract x-only pubkey from tapscript and verify signature.
      final Uint8List scriptWithLen = Uint8List.fromList(
          [...Codec.encodeVariableInteger(scriptBytes.length), ...scriptBytes]);
      final List<dynamic> cmds = Script.parseToCommand(scriptWithLen);
      // InheritancePolicy script shape: <locktime> CLTV DROP <pubkey> CHECKSIG
      Uint8List pubkey =
          cmds.whereType<Uint8List>().last; // last pushed data is pubkey
      // Tapscript expects 32-byte x-only pubkey. Some older fixtures may use
      // 33-byte compressed keys; normalize those to x-only.
      if (pubkey.length == 33 && (pubkey[0] == 0x02 || pubkey[0] == 0x03)) {
        pubkey = pubkey.sublist(1);
      }
      if (pubkey.length != 32) return false;

      return Ecc.verifySchnorr(message, pubkey, signature);
    }

    test('Key Path Validator Test', () {
      // Bitcoin Core: mandatory-script-verify-flag-failed (Invalid Schnorr signature)
      // → Taproot key-path에서 BIP340 검증이 실패할 때. 아래는 동일 입력에 대해
      // TapSighash + witness 서명이 올바를 때 Ecc.verifySchnorr 가 통과함을 본다.
      String prevTx =
          '02000000000101df796cf8db4f1bbb45bc99b7d8f0f45612e7fad116515bd382b8a9a5edf886570100000000feffffff02085200000000000022512011ea1ebca0e3516547053f7557ba80157c24118a4f8a81108bfe299c537e23266bb74c892d010000225120ee6e66fcc1dc5b2d683191891e539738b5d9b29341c33ed4cd542ad1ce983e080140e49b267e97a8b0f298e0cb5e0f9040bfe0c42dabe533cbd4aa05c19a952cc2bef768f71c99e76f66ce3af37a0e1f47a72fdf0610883f39d46decdec9bb4f6c2018ab0200';
      String currTx =
          '0200000000010193a27471ed01812438ede377c3df354f18ad135792544b14c7b8f7d2a435aee70000000000ffffffff0288130000000000002251201d8e1f53f8d6d9956386ef566713e4974ad7eab604c233eba521d3aa6acae7326c3d0000000000002251203be0e447acfa88e442ebee74f5af49f8ddb75aecd05029e50777ff3f6aa47ea401406ee802e05d8aa640bb820e65e5810c6bce8f6794ad4f6c8e79c9ffb3ae09518327a42c13a41a6b065d67d31c7f678d28a77c6a985515ef2f47340b660164d4f600000000';
      int inputIndex = 0;

      bool isValid = validateKeyPath(prevTx, currTx, inputIndex);
      expect(isValid, isTrue);
    });

    test('Script Path Validator Test', () {
      String prevTx =
          '0200000000010100000000000000000000000000000000000000000000000000000000000000000000000000ffffffff01085200000000000022512054c3163acb2151ec66d0612bca7870cf130645e0430ef1ba4935acece5d9afe00000000000';
      String currTx =
          '02000000000101a99148bc4f96a92c3392dee286ea981702cc6f7e5818b7d9fe709bab337416f40000000000feffffff02204e000000000000160014334924eaf46e806e86b3537a12f81595030d73a759030000000000002251203fbf8c4a2c770c6f27804f19c3e774f171f289fd2d4b4f56c165a92c5a33d98f034075a7fcfff5ee4b731a9f3fc2e0ed8afd33b7dc23ec8deeaf5714664bb5e277099681d9d63867c5082613e58820ff1dd7aed6bb4cc89b3251c10ac3ec722de4f5290400b95569b17520d78db5d7e748a8d914a86da5e406303a7156c06a1534f89ab70a02cbeec9ee84ac41c033a2310b5332888679eb9895a6b7297d6fd94620695f38ab98beb17c8b170d1472b08c64086873757013cb1eddc9dcc49a5555d4c58a59307c77bb2ce8f5c57d00b95569';
      int inputIndex = 0;
      bool isValid = validateScriptPath(prevTx, currTx, inputIndex);
      expect(isValid, isTrue);
    });

    test('P2TR MuSig2 Test (case 1)', () {
      late KeyStore keyStore1;
      late KeyStore keyStore2;
      late TaprootVault vault;

      NetworkType.setNetworkType(NetworkType.regtest);

      SingleSignatureVault vault1 =
          MockFactory.createP2wpkhVault(passphrase: 'A');
      SingleSignatureVault vault2 =
          MockFactory.createP2wpkhVault(passphrase: 'B');

      keyStore1 = KeyStore.fromSeed(vault1.keyStore.seed, AddressType.p2tr);
      keyStore2 = KeyStore.fromSeed(vault2.keyStore.seed, AddressType.p2tr);

      int addressIndex = 1;

      vault = TaprootVault.fromKeyStoreList([keyStore1, keyStore2], []);

      Utxo utxo = Utxo(
          '5786f8eda5a9b882d35b5116d1fae71256f4f0d8b799bc45bb1b4fdbf86c79df',
          0,
          21000,
          "m/86'/1'/0'/0/$addressIndex");
      Transaction tx = Transaction.forSinglePayment([utxo],
          MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 1000, 3, vault);
      String unsignedPsbt = Psbt.fromTransaction(tx, vault).serialize();
      String noncePsbt = vault.addPublicNonce(unsignedPsbt);
      String signedPsbt = vault.addSignatureToPsbt(noncePsbt);
      Transaction signedTx =
          Psbt.parse(signedPsbt).getSignedTransaction(AddressType.p2tr);
      expect(Codec.decodeHex(signedTx.inputs.single.witnessList.single),
          hasLength(64));
      expect(Transaction.parse(signedTx.serialize()).serialize(),
          signedTx.serialize());
    });

    test('P2TR MuSig2 Test (case 2)', () {
      late KeyStore keyStore1;
      late KeyStore keyStore2;
      late TaprootVault vault;

      NetworkType.setNetworkType(NetworkType.regtest);

      SingleSignatureVault vault1 =
          MockFactory.createP2wpkhVault(passphrase: 'A');
      SingleSignatureVault vault2 =
          MockFactory.createP2wpkhVault(passphrase: 'B');

      keyStore1 = KeyStore.fromSeed(vault1.keyStore.seed, AddressType.p2tr);
      keyStore2 = KeyStore.fromSeed(vault2.keyStore.seed, AddressType.p2tr);

      int addressIndex = 0;

      vault = TaprootVault.fromKeyStoreList([keyStore1, keyStore2], []);

      Utxo utxo = Utxo(
          '9953d794bd9d939b96ad7b7d17df7524c41078d6517514fe6349fcdfbd8d78cb',
          1,
          21000,
          "m/86'/1'/0'/0/$addressIndex");
      Transaction tx = Transaction.forSinglePayment([utxo],
          MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 1000, 3, vault);
      String unsignedPsbt = Psbt.fromTransaction(tx, vault).serialize();
      String noncePsbt = vault.addPublicNonce(unsignedPsbt);
      String signedPsbt = vault.addSignatureToPsbt(noncePsbt);

      Transaction signedTx =
          Psbt.parse(signedPsbt).getSignedTransaction(AddressType.p2tr);
      expect(Codec.decodeHex(signedTx.inputs.single.witnessList.single),
          hasLength(64));
      expect(Transaction.parse(signedTx.serialize()).serialize(),
          signedTx.serialize());
    });

    test('P2TR Key Path Spending Test', () {
      WalletUtility.getAccountIndexFromDerivationPath("m/86'/1'/0'/0/0");
      NetworkType.setNetworkType(NetworkType.regtest);

      TaprootVault vault = MockFactory.createP2trKeyPathSpendingVault();
      int addressIndex = 3;

      expect(vault.descriptor.hashCode, 917163750);
      expect(vault.getAddress(addressIndex),
          'bcrt1prxdp6w8rvnlhy7jpq9er26wwc663wcjqk2p8yv2x6xelwudvedksemnydv');
      Utxo utxo = Utxo(
          '83ff14d4ec99062d9f84793d878320096dd3c3e7fe3cc500fc7e83540ac33b7d',
          0,
          21000,
          "m/86'/1'/0'/0/$addressIndex");

      Transaction tx = Transaction.forSinglePayment([utxo],
          MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vault);
      Psbt unsignedPsbt = Psbt.fromTransaction(tx, vault);
      expect(unsignedPsbt.addressType, AddressType.p2tr);
      //String noncePsbt = vault.addPublicNonce(unsignedPsbt.serialize());
      Psbt signedPsbt =
          Psbt.parse(vault.addSignatureToPsbt(unsignedPsbt.serialize()));
      Transaction signedTx = signedPsbt.getSignedTransaction(AddressType.p2tr);
      expect(signedTx, isA<Transaction>());
      expect(signedTx.transactionHash,
          '65cad85bcc9ccb1b69197061a426a94f83e72fb24d50e7a8f878f48580ed02b2');
    });

    test('P2TR Key Path Spending Test with extra input', () {
      WalletUtility.getAccountIndexFromDerivationPath("m/86'/1'/0'/0/0");
      NetworkType.setNetworkType(NetworkType.regtest);

      TaprootVault vault = MockFactory.createP2trKeyPathSpendingVault();
      int addressIndex = 4;

      expect(vault.getAddress(addressIndex),
          'bcrt1pz85pwjc5up7wmx8kjdpg226y3j7nr49dvjcug62mycs7tx4h7vkselrrv5');
      Utxo utxo = Utxo(
          '0c8b3439db31c8ca74768288d68714c18a3f8ef8ac2592549413d96335a4b778',
          1,
          21000,
          "m/86'/1'/0'/0/$addressIndex");

      Transaction tx = Transaction.forSinglePayment([utxo],
          MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vault);
      Psbt unsignedPsbt = Psbt.fromTransaction(tx, vault);
      expect(unsignedPsbt.addressType, AddressType.p2tr);
      String noncePsbt = vault.addPublicNonce(unsignedPsbt.serialize(),
          extraInput:
              '0101010101010101010101010101010101010101010101010101010101010101');
      Psbt signedPsbt = Psbt.parse(vault.addSignatureToPsbt(noncePsbt));
      Transaction signedTx = signedPsbt.getSignedTransaction(vault.addressType);
      expect(signedTx, isA<Transaction>());
      // print(signedTx.serialize());
      expect(signedTx.transactionHash,
          '4864b06bf9086c8ff1d8ff503b6209957394d2fded675d7b5e3b793a3427e242');
    });

    test('P2TR key-path wallet with one key signs transaction', () {
      TaprootVault vault = MockFactory.createP2trKeyPathSpendingVault();
      int addressIndex = 0;

      expect(vault.keyStoreList.length, 1);

      Transaction prevTx = Transaction.withInputsAndOutputs(
        [
          TransactionInput.forPayment(
            '0000000000000000000000000000000000000000000000000000000000000000',
            0,
          )
        ],
        [TransactionOutput.forPayment(21000, vault.getAddress(addressIndex))],
        AddressType.p2tr,
      );
      Utxo utxo =
          Utxo(prevTx.transactionHash, 0, 21000, "m/86'/1'/0'/0/$addressIndex");

      Transaction tx = Transaction.forSinglePayment([utxo],
          MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vault);
      Psbt unsignedPsbt = Psbt.fromTransaction(tx, vault);

      expect(unsignedPsbt.matchesVault(vault), isTrue);
      expect(unsignedPsbt.addressType, AddressType.p2tr);

      Psbt signedPsbt =
          Psbt.parse(vault.addSignatureToPsbt(unsignedPsbt.serialize()));
      Transaction signedTx = signedPsbt.getSignedTransaction(vault.addressType);

      expect(
          validateKeyPath(prevTx.serialize(), signedTx.serialize(), 0), isTrue);
      expect(signedTx.inputs[0].witnessList.length, 1);
      expect(signedTx.inputs[0].witnessList[0].length, 128);
    });

    test(
        'P2TR key-path signing with single-key vault that has tapscript policies',
        () {
      KeyStore keyStore = KeyStore.fromSeed(
          Seed.fromMnemonic(
              utf8.encode(
                  'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
              passphrase: utf8.encode('parent')),
          AddressType.p2tr);
      TaprootVault beneficiaryVault =
          MockFactory.createBeneficiaryVault(passphrase: 'child');
      Policy inheritancePolicy = InheritancePolicy.fromDescriptorAndLocktime(
          beneficiaryVault.descriptor, 1767225600);

      TaprootVault vault =
          TaprootVault.fromKeyStoreList([keyStore], [inheritancePolicy]);

      int addressIndex = 0;
      Transaction prevTx = Transaction.withInputsAndOutputs(
        [
          TransactionInput.forPayment(
            '0000000000000000000000000000000000000000000000000000000000000000',
            0,
          )
        ],
        [TransactionOutput.forPayment(21000, vault.getAddress(addressIndex))],
        AddressType.p2tr,
      );
      Utxo utxo =
          Utxo(prevTx.transactionHash, 0, 21000, "m/86'/1'/0'/0/$addressIndex");

      Transaction tx = Transaction.forSinglePayment([utxo],
          MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vault);
      Psbt unsignedPsbt = Psbt.fromTransaction(tx, vault);

      expect(unsignedPsbt.addressType, AddressType.p2tr);
      expect(unsignedPsbt.inputs[0].tapMerkleRoot, isNotNull);
      expect(unsignedPsbt.inputs[0].tapLeafScript, isNull);

      Psbt signedPsbt =
          Psbt.parse(vault.addSignatureToPsbt(unsignedPsbt.serialize()));
      Transaction signedTx = signedPsbt.getSignedTransaction(vault.addressType);

      expect(
          validateKeyPath(prevTx.serialize(), signedTx.serialize(), 0), isTrue);
      expect(signedTx.inputs[0].witnessList.length, 1);
      expect(signedTx.inputs[0].witnessList[0].length, 128);
    });

    test(
        'P2TR inheritance child cannot sign key-path transaction without policy',
        () {
      KeyStore parentKeyStore = KeyStore.fromSeed(
          Seed.fromMnemonic(
              utf8.encode(
                  'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
              passphrase: utf8.encode('parent')),
          AddressType.p2tr);
      TaprootVault childSingleVault =
          MockFactory.createBeneficiaryVault(passphrase: 'child');
      Policy inheritancePolicy = InheritancePolicy.fromDescriptorAndLocktime(
          childSingleVault.descriptor, 1767225600);

      TaprootVault parentSingleVault =
          TaprootVault.fromKeyStoreList([parentKeyStore], []);
      TaprootVault vault = TaprootVault.fromKeyStoreList(
          [KeyStore.fromSignerBsms(parentSingleVault.getSignerBsms('parent'))],
          [inheritancePolicy]);
      TaprootVault childVault =
          TaprootVault.fromCoordinatorBsms(vault.getCoordinatorBsms());
      childVault
          .bindSeedToBeneficiaryKeyStore(childSingleVault.keyStoreList[0].seed);

      int addressIndex = 0;
      Transaction prevTx = Transaction.withInputsAndOutputs(
        [
          TransactionInput.forPayment(
            '0000000000000000000000000000000000000000000000000000000000000000',
            0,
          )
        ],
        [TransactionOutput.forPayment(21000, vault.getAddress(addressIndex))],
        AddressType.p2tr,
      );
      Utxo utxo =
          Utxo(prevTx.transactionHash, 0, 21000, "m/86'/1'/0'/0/$addressIndex");
      Transaction tx = Transaction.forSinglePayment([utxo],
          MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, childVault);

      Psbt unsignedPsbt = Psbt.fromTransaction(tx, childVault);

      expect(unsignedPsbt.inputs[0].tapLeafScript, isNull);
      expect(() => childVault.addSignatureToPsbt(unsignedPsbt.serialize()),
          throwsException);
    });

    test(
        'P2TR inheritance parent cannot sign script-path transaction after setPolicy',
        () {
      KeyStore parentKeyStore = KeyStore.fromSeed(
          Seed.fromMnemonic(
              utf8.encode(
                  'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
              passphrase: utf8.encode('parent')),
          AddressType.p2tr);
      TaprootVault childSingleVault =
          MockFactory.createBeneficiaryVault(passphrase: 'child');
      Policy inheritancePolicy = InheritancePolicy.fromDescriptorAndLocktime(
          childSingleVault.descriptor, 1767225600);

      TaprootVault parentSingleVault =
          TaprootVault.fromKeyStoreList([parentKeyStore], []);
      TaprootVault vault = TaprootVault.fromKeyStoreList(
          [KeyStore.fromSignerBsms(parentSingleVault.getSignerBsms('parent'))],
          [inheritancePolicy]);
      TaprootVault parentVault =
          TaprootVault.fromCoordinatorBsms(vault.getCoordinatorBsms());
      parentVault.bindSeedToKeyStore(parentKeyStore.seed);

      TaprootVault childVault =
          TaprootVault.fromCoordinatorBsms(vault.getCoordinatorBsms());
      childVault
          .bindSeedToBeneficiaryKeyStore(childSingleVault.keyStoreList[0].seed);
      TaprootWallet wallet = TaprootWallet.fromDescriptor(vault.descriptor);
      final walletPolicy = wallet.policyList[0];

      int addressIndex = 0;
      Transaction prevTx = Transaction.withInputsAndOutputs(
        [
          TransactionInput.forPayment(
            '0000000000000000000000000000000000000000000000000000000000000000',
            0,
          )
        ],
        [TransactionOutput.forPayment(21000, vault.getAddress(addressIndex))],
        AddressType.p2tr,
      );
      Utxo utxo =
          Utxo(prevTx.transactionHash, 0, 21000, "m/86'/1'/0'/0/$addressIndex");
      Transaction tx = Transaction.forSinglePayment([utxo],
          MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, childVault);
      tx.setPolicy(walletPolicy);

      Psbt unsignedPsbt = Psbt.fromTransaction(tx, childVault);

      expect(unsignedPsbt.inputs[0].tapLeafScript, isNotNull);
      expect(() => parentVault.addSignatureToPsbt(unsignedPsbt.serialize()),
          throwsException);
    });

    test('P2TR MuSig2 spending (parent multisig spending)', () {
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
      Policy policy1 = InheritancePolicy.fromDescriptorAndLocktime(
          MockFactory.createBeneficiaryVault(passphrase: 'A').descriptor,
          1767225600);
      Policy policy2 = InheritancePolicy.fromDescriptorAndLocktime(
          MockFactory.createBeneficiaryVault(passphrase: 'B').descriptor,
          1767225600);
      Policy policy3 = InheritancePolicy.fromDescriptorAndLocktime(
          MockFactory.createBeneficiaryVault(passphrase: 'C').descriptor,
          1767225600);
      TaprootVault dadSingleVault =
          TaprootVault.fromKeyStoreList([keyStore1], []);
      TaprootVault momSingleVault =
          TaprootVault.fromKeyStoreList([keyStore2], []);
      TaprootVault vault = TaprootVault.fromKeyStoreList([
        KeyStore.fromSignerBsms(dadSingleVault.getSignerBsms("dad")),
        KeyStore.fromSignerBsms(momSingleVault.getSignerBsms("mom"))
      ], [
        policy1,
        policy2,
        policy3
      ]);

      TaprootVault dadVault =
          TaprootVault.fromCoordinatorBsms(vault.getCoordinatorBsms());
      dadVault.bindSeedToKeyStore(keyStore1.seed);

      TaprootVault momVault =
          TaprootVault.fromCoordinatorBsms(vault.getCoordinatorBsms());
      momVault.bindSeedToKeyStore(keyStore2.seed);

      int addressIndex = 1;
      expect(vault.getAddress(addressIndex),
          'bcrt1p0jtzj2ukjewq7x20kl8g6zq3aph5sq3v2lf6nnfzqu9n9ft4u8pqu7yysc');

      Utxo utxo = Utxo(
          'c996762bdaace673568b5ba574eb8faf8f6ff6c2bc3c0524820610f913f95b84',
          0,
          21000,
          "m/86'/1'/0'/0/$addressIndex");

      Transaction tx = Transaction.forSinglePayment([utxo],
          MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vault);
      // tx.addPolicy(vault.policyList[0].toScript(addressIndex).serialize(),
      //     vault.getControlBlock(0, addressIndex, isChange: false));

      Psbt unsignedPsbt = Psbt.fromTransaction(tx, vault);
      // print(unsignedPsbt.serialize());
      String dadNoncePsbt = dadVault.addPublicNonce(unsignedPsbt.serialize());
      String momNoncePsbt = momVault.addPublicNonce(dadNoncePsbt);
      String momSignedPsbt = momVault.addSignatureToPsbt(momNoncePsbt);
      String dadSignedPsbt = dadVault.addSignatureToPsbt(momSignedPsbt);
      Psbt signedPsbt = Psbt.parse(dadSignedPsbt);
      //Psbt momSignedPsbt = Psbt.parse(momVault.addSignatureToPsbt(dadSignedPsbt));
      Transaction signedTx =
          signedPsbt.getSignedTransaction(dadVault.addressType);

      // print(signedTx.serialize());
      String prevTx =
          '020000000001032c709331a74a30f5b0fdc53b62c1732a960c6a315f237bb2a73109b7c006431f0000000000fefffffffb28d12d5206bb911ff1a9b4fef1e48d4debca59d4ac47868de5fa502cec33cd0100000000feffffff9a02b25144cfff5665931210cc46d3af950ee81cde0c52faef40e1f5a9477dd30000000000feffffff0208520000000000002251207c96292b96965c0f194fb7ce8d0811e86f48022c57d3a9cd22070b32a575e1c21d2c189a2a01000022512028a5013c1c7e5226d4cd795c6008f46e52291d9a20df8c231adcbf61ad340e440247304402205a817286a25fbf31914838357cc5e90b2fc745d00c9fb533ccb9ecaa96cbd6ce02201fe7e6d6c6702efcc3663712ecd16ea5e5d5dfdda4e5b2e44413989effa4e2e5012103d53b62963d4db8920c8687abd0934482b4ba798326cfaa0b81fd7d50928339e602473044022024318a4f67bdb822359208d1f8f93b24a42b98e6be4d1ca5e8870ada3b647afa02204962670db40ba9db90881414e855c1fb4424abd753bb52646f87f821be600024012102d12a59fbe73795a32b464de321fd73bf6b326486c5dd2f61e9ebae229c25daa10247304402201d62c4953e0a67598931efc3a79c4e7209118d47ab07b76dfb69427a86b0922c022068b5794eae41c3830a7633d546718719da5f6399a09c9ee3cc7bc0c3718ce7de012103a6ed911d56eeec6708ec232abe3cdd9be4f3c75127dbe5b61f72351b6a1c6f2c7a390300';
      expect(validateKeyPath(prevTx, signedTx.serialize(), 0), isTrue);
      // print(signedTx.serialize());
      expect(signedTx.transactionHash,
          '657b9232039a25ba185e3542fc14f72af931ac7ed91f4d5521ab064288c6988a');
      // Random nonces change the witness and wtxid, but not the txid.
    });

    test('P2TR Script Path spending (child spending)', () {
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
      Policy policy1 = InheritancePolicy.fromDescriptorAndLocktime(
          MockFactory.createBeneficiaryVault(passphrase: 'P1').descriptor,
          1767225600);
      Policy policy2 = InheritancePolicy.fromDescriptorAndLocktime(
          MockFactory.createBeneficiaryVault(passphrase: 'P2').descriptor,
          1767225600);
      Policy policy3 = InheritancePolicy.fromDescriptorAndLocktime(
          MockFactory.createBeneficiaryVault(passphrase: 'P3').descriptor,
          1767225600);
      TaprootVault dadSingleVault =
          TaprootVault.fromKeyStoreList([keyStore1], []);
      TaprootVault momSingleVault =
          TaprootVault.fromKeyStoreList([keyStore2], []);
      TaprootVault childSingleVault =
          MockFactory.createBeneficiaryVault(passphrase: 'P1');
      TaprootVault vault = TaprootVault.fromKeyStoreList([
        KeyStore.fromSignerBsms(dadSingleVault.getSignerBsms("dad")),
        KeyStore.fromSignerBsms(momSingleVault.getSignerBsms("mom"))
      ], [
        policy1,
        policy2,
        policy3
      ]);

      TaprootVault dadVault =
          TaprootVault.fromCoordinatorBsms(vault.getCoordinatorBsms());
      dadVault.bindSeedToKeyStore(keyStore1.seed);

      TaprootVault momVault =
          TaprootVault.fromCoordinatorBsms(vault.getCoordinatorBsms());
      momVault.bindSeedToKeyStore(keyStore2.seed);

      TaprootVault childVault =
          TaprootVault.fromCoordinatorBsms(vault.getCoordinatorBsms());
      childVault
          .bindSeedToBeneficiaryKeyStore(childSingleVault.keyStoreList[0].seed);

      int addressIndex = 1;

      expect(vault.getAddress(addressIndex),
          'bcrt1ppkpv0v7n5e8e3j7wqchrs0mgwdcu40datf0x93kg3cnsy6puzwds70a5qq');

      Utxo utxo = Utxo(
          '0b5b43a8a09f1021bac4f4357c2808043b409231b42fc0143050ac37668a984b',
          0,
          21000,
          "m/86'/1'/0'/0/$addressIndex");

      Transaction tx = Transaction.forSinglePayment([utxo],
          MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 20000, 1, childVault);

      TaprootWallet wallet = TaprootWallet.fromDescriptor(vault.descriptor);

      final noPolicyPsbt = Psbt.fromTransaction(tx, childVault);
      expect(noPolicyPsbt.inputs.any((input) => input.tapLeafScript != null),
          isFalse);

      final walletPolicy = wallet.policyList[1];

      tx.setPolicy(walletPolicy);

      // Build PSBT using the wallet that owns the UTXO (parentVault),
      // then sign via beneficiaryVault using script path.
      Psbt unsignedPsbt = Psbt.fromTransaction(tx, childVault);
      //   print(unsignedPsbt.serialize());
      expect(unsignedPsbt.inputs.any((input) => input.tapLeafScript != null),
          isTrue);

      SingleSignatureVault singleSignatureVault = SingleSignatureVault.fromSeed(
          Seed.fromMnemonic(
              utf8.encode(
                  'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
              passphrase: utf8.encode('A')));
      expect(unsignedPsbt.matchesVault(childVault), true);
      expect(unsignedPsbt.matchesVault(dadVault), true);
      expect(unsignedPsbt.matchesVault(momVault), true);
      expect(unsignedPsbt.matchesVault(vault), true);
      expect(unsignedPsbt.matchesVault(singleSignatureVault), false);

      // print(unsignedPsbt.serialize());
      Psbt signedPsbt =
          Psbt.parse(childVault.addSignatureToPsbt(unsignedPsbt.serialize()));
      Transaction signedTx = signedPsbt.getSignedTransaction(AddressType.p2tr);

      final Transaction prevTx = Transaction.parse(
          '02000000000106ff8ceca412729522c0c3ac1ce941cb0486a1d32f4e15ac61536293b9edfb5d1e0000000000feffffff3c4ecb1fb3cfaebf753bd1ca1b5f6a76ffc45307f5994f422f1e6fff851646340000000000feffffffc9fb3a44b947d3b0e018647fd5df70ed3fa7a5fbc387b7149ba1ef50bb3b674e0000000000feffffff6e04af098b63d7b54bb9482b8e5635486b606c19e6ba0d6de04d562ebf7f4f480000000000feffffffc875fb2947fe64d06b1f19a42f29e2331eac172ae331f863173fc9bae14d6d9a0000000000fefffffff2c4017b0238af2175189d9c7a284f99e318830c91bb1a4b0c3a52bd05f17f800000000000feffffff0208520000000000002251200d82c7b3d3a64f98cbce062e383f687371cabdbd5a5e62c6c88e2702683c139b5abad59a2c0100002251207b5a56e37fc30d8d86320d2d94b08d4a622aa31c3715fe16a3d827a3d4326de7024730440220595adcf4899af39f4f4d81d7c1180db866865214a8351e5e8f25a3e6ab90ec1702200aa504d7c46dffa5e0df93b84d4f9b3807677b835723e07d101703e0ddb75813012103af7396fafb8e6f562e3dbc56ef521ef927e16a13d9c680a66b1e5064f7df7b52024730440220258c211b256687b3b5184fa554b1c37cc260b3d59507a1637d9efba5d62a4e3d0220515d34c92ec632938452e53369f36af45ee52db05ca4f8f371242fbd867b6880012103413a94f36c6ecf1279f4417ce08f83f8806f64844d7ed58accab521e2bf2df9102473044022071ceddbf4ed48a70063a06d415e0493f568da482bb835bfaf6a52d366947ff2a02205f090c139d47bf46a86900ab89b28ef4e11ff2e3ed6eee99da0c3e9d9d88ad2d012102bbe65cc7bda8508543e34c8637fb2d697be490c450ed733cf802278c9f61bdee024730440220479c7509039c5991185ef564fc05eb11c8a7b90523cbe05c103bdb6128ba3c2102202880e6a2bb0c93edcba14896c9ba49e349491fc8318af93df28e22779ab048ab012103eb6334a26e0ff5e6e4a04454e81797c22e5d2e3afef9187cccc32ca6c4dcc8250247304402202c84a685b561430b2ad5a6c4920bd884f18821090b4a6f133ea62b385fd94119022033cdd701c6168547b283e659d1bb931861d91dfabdd74fcaca19c18a176975e3012102a272b9d73bd3cb50198becac61e7451e252395463999042d695889899e4e328c0247304402206652aaf305e811e35705b0ba370ddf00ae62ee434c0956ad73e2c49010bc238a022059ff5b8208a38fe8cc59e09a6e3cb510739dfbc1618875cba70574a00f5c7282012102c6bdc0c3909425857f54a183e61fb5f68d2b78bb087b10dadf805201be390c01efe80200');

      expect(validateScriptPath(prevTx.serialize(), signedTx.serialize(), 0),
          isTrue);
      expect(signedTx.transactionHash,
          '0be4c11350f38f3e4f3f49e2ad0811855886a8d9aacad0a0bab024948eef53b8');
      expect(signedTx.inputs[0].witnessList.length, 3);
      expect(
          signedTx.inputs[0].witnessList[0].length, 128); // 64-byte schnorr sig
    });
  });
}
