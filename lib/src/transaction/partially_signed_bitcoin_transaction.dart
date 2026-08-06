part of '../../coconut_lib.dart';

/// Represents a PSBT(BIP-0174).
class Psbt {
  /// @nodoc
  static Map<int, String> globalKeyType = {
    0: 'UNSIGNED_TX',
    1: 'XPUB',
    2: 'TX_VERSION',
    3: 'LOCKTIME',
    4: 'TX_IN_COUNT',
    5: 'TX_OUT_COUNT',
    6: 'TX_MODIFIABLE',
    251: 'VERSION',
    252: 'PROPRIETARY'
  };

  /// @nodoc
  static Map<int, String> inputKeyType = {
    0: 'NON_WITNESS_UTXO',
    1: 'WITNESS_UTXO',
    2: 'PARTIAL_SIG',
    3: 'SIGHASH_TYPE',
    4: 'REDEEM_SCRIPT',
    5: 'WITNESS_SCRIPT',
    6: 'BIP32_DERIVATION',
    7: 'FINAL_SCRIPTSIG',
    8: 'FINAL_SCRIPTWITNESS',
    9: 'POR_COMMITMENT',
    10: 'RIPEMD160',
    11: 'SHA256',
    12: 'HASH160',
    13: 'HASH256',
    14: 'PREVIOUS_TXID',
    15: 'OUTPUT_INDEX',
    16: 'SEQUENCE',
    17: 'REQUIRED_TIME_LOCKTIME',
    18: 'REQUIRED_HEIGHT_LOCKTIME',
    19: 'TAP_KEY_SIG',
    20: 'TAP_SCRIPT_SIG',
    21: 'TAP_LEAF_SCRIPT',
    22: 'TAP_BIP32_DERIVATION',
    23: 'TAP_INTERNAL_KEY',
    24: 'TAP_MERKLE_ROOT',
    26: 'MUSIG2_PARTICIPANT_PUBKEY',
    27: 'MUSIG2_PUB_NONCE',
    28: 'MUSIG2_PARTIAL_SIG',
    252: 'PROPRIETARY'
  };

  /// @nodoc
  static Map<int, String> outputKeyType = {
    0: 'REDEEM_SCRIPT',
    1: 'WITNESS_SCRIPT',
    2: 'BIP32_DERIVATION',
    3: 'AMOUNT',
    4: 'SCRIPT',
    5: 'TAP_INTERNAL_KEY',
    6: 'TAP_TREE',
    7: 'TAP_BIP32_DERIVATION',
    8: 'MUSIG2_PARTICIPANT_PUBKEYS',
    252: 'PROPRIETARY'
  };

  /// @nodoc
  Map<String, dynamic> psbtMap;

  /// Get transaction not signed yet.
  Transaction? unsignedTransaction;

  /// @nodoc
  List<DerivationPath> globalExtendedPublicKeyList = [];

  /// @nodoc
  List<PsbtInput> inputs = [];

  /// @nodoc
  List<PsbtOutput> outputs = [];

  /// @nodoc
  List<DerivationPath> extendedPublicKeyList = [];

  /// @nodoc
  bool isFromCoconut = false;

  /// @nodoc
  String? identifier;

  /// Get the fee of the transaction.
  int get fee => () {
        int totalInput = 0;
        int totalOutput = 0;
        if (inputs.isEmpty) {
          throw Exception('Inputs are empty');
        }
        for (int i = 0; i < inputs.length; i++) {
          if (inputs[i].witnessUtxo == null) {
            throw Exception('Witness UTXO is null');
          }
          totalInput += inputs[i].witnessUtxo!.amount;
        }
        for (int i = 0; i < unsignedTransaction!.outputs.length; i++) {
          totalOutput += unsignedTransaction!.outputs[i].amount;
        }
        return totalInput - totalOutput;
      }();

  /// Get the sending amount, excluding change verified against [wallet].
  int sendingAmount(WalletBase wallet) {
    int sendingAmount = 0;
    for (PsbtOutput output in outputs) {
      if (output.isChange(wallet)) continue;
      sendingAmount += output.outAmount!;
    }

    return sendingAmount;
  }

  AddressType? get addressType => () {
        if (inputs.isEmpty) {
          throw Exception('Inputs are empty');
        }
        if (inputs[0].bip32Derivation != null) {
          if (inputs[0].witnessScript == null) {
            return AddressType.p2wpkh;
          } else {
            return AddressType.p2wsh;
          }
        } else if (inputs[0].tapBip32Derivation != null) {
          return AddressType.p2tr;
        } else {
          return null;
        }
      }();

  bool isForVault(WalletBase wallet) {
    if (wallet is SingleSignatureVault) {
      KeyStore keyStore = wallet.keyStore;
      if (keyStore.extendedPublicKey.serializeForPsbt(toXpub: true) !=
          globalExtendedPublicKeyList.first.publicKey) {
        return false;
      }
      if (globalExtendedPublicKeyList.first.masterFingerprint !=
          keyStore.masterFingerprint) {
        return false;
      }
      if (globalExtendedPublicKeyList.first.path != wallet.derivationPath) {
        return false;
      }
      if (isFromCoconut == true &&
          (identifier != Codec.encodeHex(Hash.sha256(wallet.descriptor)))) {
        return false;
      }
      return true;
    } else if (wallet is MultisignatureVault) {
      if (wallet.keyStoreList.length != globalExtendedPublicKeyList.length) {
        return false;
      }
      List<String> pubInVaultList = [];
      for (KeyStore keyStore in wallet.keyStoreList) {
        pubInVaultList
            .add(keyStore.extendedPublicKey.serializeForPsbt(toXpub: true));
      }
      List<String> pubInPsbtList = [];
      for (DerivationPath derivationPath in globalExtendedPublicKeyList) {
        pubInPsbtList.add(derivationPath.publicKey);
      }
      pubInPsbtList.sort();
      pubInVaultList.sort();
      if (pubInVaultList.join('') != pubInPsbtList.join('')) {
        print('pubInVaultList: $pubInVaultList');
        print('pubInPsbtList: $pubInPsbtList');
        return false;
      }
      if (wallet.requiredSignature !=
          inputs[0].witnessScript!.getRequiredSignature()) {
        return false;
      }
      if (isFromCoconut == true &&
          (identifier != Codec.encodeHex(Hash.sha256(wallet.descriptor)))) {
        return false;
      }
      return true;
    } else if (wallet is TaprootVault) {
      List<String> pubInVaultList = [];
      for (KeyStore keyStore in wallet.keyStoreList) {
        pubInVaultList
            .add(keyStore.extendedPublicKey.serializeForPsbt(toXpub: true));
      }
      for (Policy policy in wallet.policyList) {
        if (policy is InheritancePolicy) {
          pubInVaultList.add(policy.beneficiaryKeyStore.extendedPublicKey
              .serializeForPsbt(toXpub: true));
        }
      }
      if (pubInVaultList.length != globalExtendedPublicKeyList.length) {
        return false;
      }
      if (isFromCoconut == true &&
          (identifier != Codec.encodeHex(Hash.sha256(wallet.descriptor)))) {
        return false;
      }
      return true;
    } else {
      return false;
    }
  }

  /// @nodoc
  Psbt(this.psbtMap) {
    unsignedTransaction =
        Transaction.parseUnsignedTransaction(psbtMap["global"]["00"]);

    // instantiate global
    psbtMap["global"].keys.forEach((key) {
      if (key.startsWith('01')) {
        String publicKey = key.substring(2);
        final DerivationPath derivation =
            DerivationPath.fromBip32(publicKey, psbtMap["global"][key]);
        extendedPublicKeyList.add(derivation);
        globalExtendedPublicKeyList.add(derivation);
      }
      if (key.startsWith('fc07636f636f6e757401')) {
        isFromCoconut = true;
        identifier = psbtMap["global"][key];
      }
    });

    // instantiate each input
    for (int i = 0; i < psbtMap["inputs"].length; i++) {
      TransactionOutput? witnessUtxo;
      if (psbtMap["inputs"][i].containsKey("01")) {
        witnessUtxo = TransactionOutput.parse(psbtMap["inputs"][i]["01"]);
      }

      List<DerivationPath> inputDerivationPathList = [];
      List<Signature> partialSigList = [];
      List<String> finalScriptWitness = [];
      MultisignatureScript? witnessScript;

      // for every taproot
      List<DerivationPath> tapBip32Derivation = [];
      String? internalKey;

      // for key path spending
      String? taprootKeyPathSpendingSignature;

      // field for musig2
      String? muSig2AggregatedPublicKey;
      List<String>? muSig2participantPubKeyList;
      Map<String, String>? muSig2PubNonces;
      List<Signature>? muSig2PartialSigs;

      // field for script path spending
      String? tapLeafHash;
      Script? tapLeafScript;
      String? controlBlock;
      String? tapMerkleRoot;
      List<Signature> tapScriptSigList = [];

      psbtMap["inputs"][i].keys.forEach((key) {
        // 06 : BIP32_DERIVATION
        if (key.startsWith('06')) {
          String publicKey = key.substring(2);
          inputDerivationPathList.add(
              DerivationPath.fromBip32(publicKey, psbtMap["inputs"][i][key]));
        }
        // 02 : PARTIAL_SIG
        if (key.startsWith('02')) {
          String publicKey = key.substring(2);
          String signature = psbtMap["inputs"][i][key];
          partialSigList.add(Signature(signature, publicKey));
        }
        // 05 : WITNESS_SCRIPT
        if (key.startsWith('05')) {
          String script = psbtMap["inputs"][i][key];
          String size =
              Codec.encodeHex(Codec.encodeVariableInteger(script.length ~/ 2));
          witnessScript = MultisignatureScript.parse(size + script);
        }
        // 08 : FINAL_SCRIPTWITNESS
        if (key.startsWith('08')) {
          finalScriptWitness
              .addAll(_parseScriptWitness(psbtMap["inputs"][i][key]));
        }
        // 19 : TAP_KEY_SIG
        if (key.startsWith('13')) {
          taprootKeyPathSpendingSignature = psbtMap["inputs"][i][key];
        }

        // 20 : TAP_SCRIPT_SIG (non-standard simplified encoding: 0x14 || pubkey -> signature)
        if (key.startsWith('14')) {
          String publicKey = key.substring(2);
          String signature = psbtMap["inputs"][i][key];
          tapScriptSigList.add(Signature(signature, publicKey));
        }

        //21 : TAP_LEAF_SCRIPT
        if (key.startsWith('15')) {
          // Key is: 0x15 || control_block. Store only the control_block bytes.
          controlBlock = key.substring(2);
          String script = psbtMap["inputs"][i][key];

          // Value is: raw_tapscript || leaf_version (1 byte).
          final String rawScriptHex =
              psbtMap["inputs"][i][key].substring(0, script.length - 2);
          tapLeafScript = Script(Script.parseToCommand(Uint8List.fromList([
            ...Codec.encodeVariableInteger(rawScriptHex.length ~/ 2),
            ...Codec.decodeHex(rawScriptHex),
          ])));
        }
        // 23 : INTERNAL_KEY_XONLY
        if (key.startsWith('17')) {
          internalKey = psbtMap["inputs"][i][key];
        }

        // 22 : TAP_BIP32_DERIVATION
        if (key.startsWith('16')) {
          tapBip32Derivation.add(DerivationPath.fromTaproot(
              key.substring(2), psbtMap["inputs"][i][key]));
        }

        // 24 : TAP_MERKLE_ROOT
        if (key.startsWith('18')) {
          tapMerkleRoot = psbtMap["inputs"][i][key];
        }

        // 26: 'MUSIG2_PARTICIPANT_PUBKEY',
        if (key.startsWith('1a')) {
          muSig2AggregatedPublicKey = key.substring(2);
          String concatenatedPubKeys = psbtMap["inputs"][i][key];
          muSig2participantPubKeyList ??= [];
          if (concatenatedPubKeys.length % 66 != 0) {
            throw Exception(
                "Invalid participant public key list: length is not multiple of 66 (got ${concatenatedPubKeys.length})");
          }
          int numberOfKeys = concatenatedPubKeys.length ~/ 66;
          for (int i = 0; i < numberOfKeys; i++) {
            final hexPart = concatenatedPubKeys.substring(i * 66, (i + 1) * 66);
            muSig2participantPubKeyList!.add(hexPart);
          }
          // muSig2participantPubKeyList!.sort();
        }

        // 27: 'MUSIG2_PUB_NONCE'
        if (key.startsWith('1b')) {
          muSig2PubNonces ??= {};
          String publicKey = key.substring(2);
          muSig2PubNonces![publicKey] = psbtMap["inputs"][i][key];
        }

        // 28: 'MUSIG2_PARTIAL_SIG',
        if (key.startsWith('1c')) {
          muSig2PartialSigs ??= [];
          String publicKey = key.substring(2);
          String signature = psbtMap["inputs"][i][key];
          muSig2PartialSigs!.add(Signature(signature, publicKey));
        }
      });

      // Set psbt input
      PsbtInput input;
      if (inputDerivationPathList.isNotEmpty) {
        input = PsbtInput.forSegwit(
            witnessUtxo, inputDerivationPathList, partialSigList,
            witnessScript: witnessScript);
      } else if (tapBip32Derivation.isNotEmpty &&
          muSig2AggregatedPublicKey == null &&
          tapLeafScript == null) {
        input = PsbtInput.forKeyPathSpending(internalKey, witnessUtxo,
            tapBip32Derivation, taprootKeyPathSpendingSignature,
            tapMerkleRoot: tapMerkleRoot);
      } else if (tapBip32Derivation.isNotEmpty &&
          muSig2AggregatedPublicKey != null &&
          tapLeafScript == null) {
        input = PsbtInput.forMuSig2(
            internalKey,
            witnessUtxo,
            tapBip32Derivation,
            muSig2AggregatedPublicKey,
            muSig2participantPubKeyList,
            muSig2PubNonces,
            muSig2PartialSigs,
            tapMerkleRoot);
      } else if (tapBip32Derivation.isNotEmpty && tapLeafScript != null) {
        input = PsbtInput.forScriptPathSpending(
            internalKey,
            witnessUtxo,
            tapBip32Derivation,
            tapLeafHash,
            tapLeafScript,
            controlBlock,
            tapMerkleRoot);
        if (tapScriptSigList.isNotEmpty) {
          input.tapScriptSig = tapScriptSigList;
        }
      } else {
        input = PsbtInput.forSignatureOnly(witnessUtxo, partialSigList,
            witnessScript: witnessScript);
      }
      if (finalScriptWitness.isNotEmpty) {
        input.finalScriptWitness = finalScriptWitness;
      }
      inputs.add(input);
    }

    for (int i = 0; i < psbtMap["outputs"].length; i++) {
      int? amount;
      ScriptPublicKey? script;
      // if (psbtMap["outputs"][i].containsKey("03")) {
      //   amount = Converter.littleEndianToInt(
      //       Codec.decodeHex(psbtMap["outputs"][i]["03"]));
      // }

      // if (psbtMap["outputs"][i].containsKey("04")) {
      //   script = ScriptPublicKey.parse(psbtMap["outputs"][i]["04"]);
      // }
      amount = unsignedTransaction!.outputs[i].amount;
      script = unsignedTransaction!.outputs[i].scriptPubKey;

      final List<DerivationPath> outputDerivationPaths = <DerivationPath>[];
      final List<DerivationPath> outputTaprootDerivationPaths =
          <DerivationPath>[];
      MultisignatureScript? witnessScript;
      psbtMap["outputs"][i].keys.forEach((key) {
        if (key.startsWith('01')) {
          String script = psbtMap["outputs"][i][key];
          String size =
              Codec.encodeHex(Codec.encodeVariableInteger(script.length ~/ 2));
          witnessScript = MultisignatureScript.parse(size + script);
        } else if (key.startsWith('02')) {
          String publicKey = key.substring(2);
          outputDerivationPaths.add(
              DerivationPath.fromBip32(publicKey, psbtMap["outputs"][i][key]));
        } else if (key.startsWith('07')) {
          outputTaprootDerivationPaths.add(DerivationPath.fromTaproot(
              key.substring(2), psbtMap["outputs"][i][key]));
        }
      });
      outputs.add(PsbtOutput(outputDerivationPaths, amount, script,
          tapBip32Derivations: outputTaprootDerivationPaths,
          witnessScript: witnessScript));
    }
  }

  /// Generate the PSBT to base64 string.
  String serialize() {
    _updatePsbtMap();
    List<int> psbtBytes = [0x70, 0x73, 0x62, 0x74, 0xff];
    //Global
    psbtBytes.addAll(_serializeKeyMap(psbtMap["global"]));
    psbtBytes.add(0x00);
    List<dynamic> inputList = psbtMap["inputs"];
    for (int i = 0; i < inputList.length; i++) {
      psbtBytes.addAll(_serializeKeyMap(inputList[i]));
      psbtBytes.add(0x00);
    }
    List<dynamic> outputList = psbtMap["outputs"];
    for (int i = 0; i < outputList.length; i++) {
      psbtBytes.addAll(_serializeKeyMap(outputList[i]));
      psbtBytes.add(0x00);
    }

    // psbtBytes.add(0x00);
    return base64Encode(psbtBytes);
  }

  void _updatePsbtMap() {
    for (int i = 0; i < inputs.length; i++) {
      if (inputs[i].partialSig != null) {
        for (Signature signature in inputs[i].partialSig!) {
          if (!psbtMap["inputs"][i].keys.contains("02${signature.publicKey}")) {
            psbtMap["inputs"][i]["02${signature.publicKey}"] =
                signature.signature;
          }
        }
      }
      if (inputs[i].tapKeySig != null) {
        if (!psbtMap["inputs"][i].keys.contains("13")) {
          psbtMap["inputs"][i]["13"] = inputs[i].tapKeySig!;
        }
      }
      if (inputs[i].muSig2PartialSigs != null) {
        for (Signature signature in inputs[i].muSig2PartialSigs!) {
          if (!psbtMap["inputs"][i].keys.contains("1c${signature.publicKey}")) {
            psbtMap["inputs"][i]["1c${signature.publicKey}"] =
                signature.signature;
          }
        }
      }
      if (inputs[i].tapScriptSig != null) {
        for (final Signature signature in inputs[i].tapScriptSig!) {
          final String key = "14${signature.publicKey}";
          if (!psbtMap["inputs"][i].keys.contains(key)) {
            psbtMap["inputs"][i][key] = signature.signature;
          }
        }
      }
      if (inputs[i].muSig2PubNonces != null) {
        for (String publicKey in inputs[i].muSig2PubNonces!.keys) {
          psbtMap["inputs"][i]["1b$publicKey"] =
              inputs[i].muSig2PubNonces![publicKey]!;
        }
      }
      if (inputs[i].tapMerkleRoot != null) {
        if (!psbtMap["inputs"][i].keys.contains("18")) {
          psbtMap["inputs"][i]["18"] = inputs[i].tapMerkleRoot!;
        }
      }
    }
  }

  Map<String, dynamic> toKeyMap() {
    return psbtMap;
  }

  List<int> _serializeKeyMap(Map<String, dynamic> map) {
    List<int> globalBytes = [];
    map.forEach((key, value) {
      List<int> keyBytes = Codec.decodeHex(key);
      globalBytes += Codec.encodeVariableInteger(keyBytes.length);
      globalBytes += keyBytes;
      List<int> valueBytes = Codec.decodeHex(value);
      globalBytes += Codec.encodeVariableInteger(valueBytes.length);
      globalBytes += valueBytes;
    });
    return globalBytes;
  }

  /// Create a PSBT from a Transaction object.
  factory Psbt.fromTransaction(Transaction tx, WalletBase wallet) {
    if (!wallet.addressType.isSegwit) {
      throw Exception('Only Segwit address type is supported');
    }

    if (tx.utxoList.isEmpty) {
      throw Exception('No UTXOs in transaction');
    }
    for (int i = 0; i < tx.inputs.length; i++) {
      if (tx.inputs[i].transactionHash != tx.utxoList[i].transactionHash) {
        throw Exception('Transaction input and UTXO list mismatch');
      }
    }

    late SingleSignatureWalletBase singleSignatureWallet;
    if (wallet is SingleSignatureWalletBase) {
      singleSignatureWallet = wallet;
    }

    late MultisignatureWalletBase multisignatureWallet;
    if (wallet is MultisignatureWalletBase) {
      multisignatureWallet = wallet;
    }

    late TaprootWalletBase taprootWallet;
    if (wallet is TaprootWalletBase) {
      taprootWallet = wallet;
    }

    Map<String, dynamic> psbtData = {"global": {}, "inputs": [], "outputs": []};

    //Global
    Map<String, dynamic> globalData = {};
    globalData["fc07636f636f6e757401"] =
        Codec.encodeHex(Hash.sha256(wallet.descriptor));
    String txKey = getKeyType(globalKeyType, 'UNSIGNED_TX');
    globalData[txKey] = tx._serializeLegacy(); //old serialze format BIP0174

    if (wallet.addressType.isSingleSignature) {
      KeyStore keyStore = singleSignatureWallet.keyStore;
      String key =
          "${getKeyType(globalKeyType, 'XPUB')}${keyStore.extendedPublicKey.serializeForPsbt(toXpub: true)}";
      String value =
          "${keyStore.masterFingerprint}${Codec.encodeHex(_serializeDerivationPath(wallet.derivationPath))}";
      globalData[key] = value;
    }

    if (wallet.addressType.isMultisignature) {
      for (KeyStore keyStore in multisignatureWallet.keyStoreList) {
        String key =
            "${getKeyType(globalKeyType, 'XPUB')}${keyStore.extendedPublicKey.serializeForPsbt(toXpub: true)}";
        String value =
            "${keyStore.masterFingerprint}${Codec.encodeHex(_serializeDerivationPath(wallet.derivationPath))}";
        globalData[key] = value;
      }
    }

    if (wallet.addressType.isTaproot) {
      for (KeyStore keyStore in taprootWallet.keyStoreList) {
        String key =
            "${getKeyType(globalKeyType, 'XPUB')}${keyStore.extendedPublicKey.serializeForPsbt(toXpub: true)}";
        String value =
            "${keyStore.masterFingerprint}${Codec.encodeHex(_serializeDerivationPath(wallet.derivationPath))}";
        globalData[key] = value;
      }
      for (Policy policy in taprootWallet.policyList) {
        if (policy is InheritancePolicy) {
          String key =
              "${getKeyType(globalKeyType, 'XPUB')}${policy.beneficiaryKeyStore.extendedPublicKey.serializeForPsbt(toXpub: true)}";
          String value =
              "${policy.beneficiaryKeyStore.masterFingerprint}${Codec.encodeHex(_serializeDerivationPath(wallet.derivationPath))}";
          globalData[key] = value;
        }
      }
    }

    psbtData["global"] = globalData;
    //Input
    List<TransactionOutput> witnessUtxoList = [];

    for (int i = 0; i < tx.inputs.length; i++) {
      String receivedAddress =
          wallet.getAddressWithDerivationPath(tx.utxoList[i].derivationPath);
      TransactionOutput output =
          TransactionOutput.forPayment(tx.utxoList[i].amount, receivedAddress);
      witnessUtxoList.add(output);
    }
    for (int i = 0; i < tx.inputs.length; i++) {
      Map<String, dynamic> inputData = {};
      String witnessUtxoKey = getKeyType(inputKeyType, 'WITNESS_UTXO');
      inputData[witnessUtxoKey] = witnessUtxoList[i].serialize();

      String sigHashTypeKey = getKeyType(inputKeyType, 'SIGHASH_TYPE');
      inputData[sigHashTypeKey] =
          Codec.encodeHex(Converter.intToLittleEndianBytes(1, 4));

      // Each address type
      if (wallet.addressType == AddressType.p2wpkh) {
        String bip32DerivationKeyType =
            getKeyType(inputKeyType, 'BIP32_DERIVATION');
        String publicKey = singleSignatureWallet.keyStore.getPublicKey(
            tx.utxoList[i].accountIndex,
            isChange: tx.utxoList[i].isChange);
        String fingerPrint = singleSignatureWallet.keyStore.masterFingerprint;

        inputData[bip32DerivationKeyType + publicKey] = fingerPrint +
            Codec.encodeHex(
                _serializeDerivationPath(tx.utxoList[i].derivationPath));

        if (tx.inputs[i].witnessList.isNotEmpty) {
          String partialSigKeyType = getKeyType(inputKeyType, 'PARTIAL_SIG');
          String publicKey = tx.inputs[i].witnessList[0];
          String signature = tx.inputs[i].witnessList[1];
          inputData[partialSigKeyType + publicKey] = signature;
        }
      } else if (wallet.addressType == AddressType.p2wsh) {
        String bip32DerivationKeyType =
            getKeyType(inputKeyType, 'BIP32_DERIVATION');
        for (KeyStore keyStore in multisignatureWallet.keyStoreList) {
          String publicKey = keyStore.getPublicKey(tx.utxoList[i].accountIndex,
              isChange: tx.utxoList[i].isChange);

          String fingerPrint = keyStore.masterFingerprint;
          inputData[bip32DerivationKeyType + publicKey] = fingerPrint +
              Codec.encodeHex(
                  _serializeDerivationPath(tx.utxoList[i].derivationPath));
        }
        String witnessScriptKey = getKeyType(inputKeyType, 'WITNESS_SCRIPT');
        String witnessScript = multisignatureWallet
            .getWitnessScript(tx.utxoList[i].derivationPath);
        inputData[witnessScriptKey] = witnessScript;

        if (tx.inputs[i].witnessList.isNotEmpty) {
          String partialSigKeyType = getKeyType(inputKeyType, 'PARTIAL_SIG');
          String publicKey = tx.inputs[i].witnessList[0];
          String signature = tx.inputs[i].witnessList[1];
          inputData[partialSigKeyType + publicKey] = signature;
        }
      } else if (wallet.addressType == AddressType.p2tr) {
        final Uint8List tapMerkleRoot = taprootWallet.getMerkleRoot(
          tx.utxoList[i].accountIndex,
          isChange: tx.utxoList[i].isChange,
        );
        //TAP_MERKLE_ROOT
        if (tapMerkleRoot.isNotEmpty) {
          String tapMerkleRootKeyType =
              getKeyType(inputKeyType, 'TAP_MERKLE_ROOT');
          inputData[tapMerkleRootKeyType] = Codec.encodeHex(tapMerkleRoot);
        }

        //TAP_INTERNAL_KEY
        String tapInternalKeyType =
            getKeyType(inputKeyType, 'TAP_INTERNAL_KEY');
        Uint8List internalKey = taprootWallet.getInternalKey(
            tx.utxoList[i].accountIndex,
            isChange: tx.utxoList[i].isChange);
        inputData[tapInternalKeyType] = Codec.encodeHex(internalKey);

        if (tx._appliedPolicy != null) {
          // Policy included
          // TAP_BIP32_DERIVATION
          if (tx._appliedPolicy is InheritancePolicy) {
            String tapBip32DerivationKeyType =
                getKeyType(inputKeyType, 'TAP_BIP32_DERIVATION');
            InheritancePolicy inheritancePolicy =
                tx._appliedPolicy as InheritancePolicy;
            KeyStore keyStore = inheritancePolicy.beneficiaryKeyStore;
            String publicKey = keyStore.getPublicKey(
                tx.utxoList[i].accountIndex,
                isChange: tx.utxoList[i].isChange,
                isXOnly: false);
            String fingerPrint = keyStore.masterFingerprint;
            String policy = Codec.encodeHex(inheritancePolicy.getTapleafHash(
                tx.utxoList[i].accountIndex,
                isChange: tx.utxoList[i].isChange));
            inputData[tapBip32DerivationKeyType + publicKey.substring(2)] =
                "01$policy$fingerPrint${Codec.encodeHex(_serializeDerivationPath(tx.utxoList[i].derivationPath))}";

            // TAP_LEAF_SCRIPT
            String tapLeafScriptType =
                getKeyType(inputKeyType, 'TAP_LEAF_SCRIPT');
            final int policyIndex = taprootWallet.policyList.indexWhere(
                (p) => p.toMiniscript() == inheritancePolicy.toMiniscript());
            if (policyIndex < 0) {
              throw Exception('Applied policy not found in wallet policy list');
            }
            String controlBlock = taprootWallet.getControlBlock(
                policyIndex, tx.utxoList[i].accountIndex,
                isChange: tx.utxoList[i].isChange);
            // PSBT TapLeafScript value must be raw tapscript bytes + leaf version.
            String leafScript = inheritancePolicy
                .toScript(tx.utxoList[i].accountIndex,
                    isChange: tx.utxoList[i].isChange)
                .rawSerialize();
            inputData[tapLeafScriptType + controlBlock] = '${leafScript}c0';
          } else {
            throw Exception('Only InheritancePolicy is supported');
          }
        } else {
          // No policy applied
          List<String> publicKeys = [];
          // TAP_BIP32_DERIVATION
          for (KeyStore keyStore in taprootWallet.keyStoreList) {
            String tapBip32DerivationKeyType =
                getKeyType(inputKeyType, 'TAP_BIP32_DERIVATION');
            String publicKey = keyStore.getPublicKey(
                tx.utxoList[i].accountIndex,
                isChange: tx.utxoList[i].isChange,
                isXOnly: false);
            publicKeys.add(publicKey);

            String fingerPrint = keyStore.masterFingerprint;

            inputData[tapBip32DerivationKeyType + publicKey.substring(2)] =
                "00$fingerPrint${Codec.encodeHex(_serializeDerivationPath(tx.utxoList[i].derivationPath))}";
          }
          if (taprootWallet.keyStoreList.length == 1) {
            // Key path spending
            if (tx.inputs[i].witnessList.isNotEmpty) {
              String taprootKeySpendSignature =
                  getKeyType(inputKeyType, 'TAP_KEY_SIG');
              inputData[taprootKeySpendSignature] = tx.inputs[i].witnessList[0];
            }
            if (tx.inputs[i].witnessList.length == 1) {
              String taprootKeySpendSignature =
                  getKeyType(inputKeyType, 'PSBT_IN_TAP_KEY_SIG');
              inputData[taprootKeySpendSignature] = tx.inputs[i].witnessList[0];
            }
          } else if (taprootWallet.keyStoreList.length > 1) {
            // MUSIG2_PARTICIPANT_PUBKEY
            String musig2ParticipantPubKeyType =
                getKeyType(inputKeyType, 'MUSIG2_PARTICIPANT_PUBKEY');
            String aggregatePubKey = Codec.encodeHex(taprootWallet
                .getAggregatedPublicKey(tx.utxoList[i].accountIndex,
                    isChange: tx.utxoList[i].isChange, isXOnly: false));
            inputData[musig2ParticipantPubKeyType + aggregatePubKey] =
                publicKeys.join();

            // String musig2PubNonceType =
            //     getKeyType(inputKeyType, 'MUSIG2_PUB_NONCE');
            for (int keyStoreIndex = 0;
                keyStoreIndex < taprootWallet.keyStoreList.length;
                keyStoreIndex++) {
              // MUSIG2_PUB_NONCE
              // if (multisignatureWallet.keyStoreList[keyStoreIndex].hasSeed) {
              //   inputData[musig2PubNonceType + publicKeys[keyStoreIndex]] =
              //       multisignatureWallet.keyStoreList[keyStoreIndex]
              //           .getMuSig2PublicNonce(
              //               tx.getTaprootSigHash(i, witnessUtxoList),
              //               aggregatePubKey,
              //               tx.utxoList[i].accountIndex,
              //               tx.utxoList[i].isChange);
              // }
            }
          }
        }
      }
      psbtData["inputs"].add(inputData);
    }

    //output
    for (int i = 0; i < tx.outputs.length; i++) {
      Map<String, dynamic> outputData = {};
      // String amountKey = getKeyType(outputKeyType, 'AMOUNT');
      // outputData[amountKey] = Codec.encodeHex(
      //     Converter.intToLittleEndianBytes(tx.outputs[i].amount, 4));

      // String scriptKey = getKeyType(outputKeyType, 'SCRIPT');
      // outputData[scriptKey] = tx.outputs[i].scriptPubKey.serialize();

      if (tx.outputs[i].derivationPath != null) {
        String bip32DerivationKeyType =
            getKeyType(outputKeyType, 'BIP32_DERIVATION');

        if (wallet is SingleSignatureWalletBase) {
          String publicKey = singleSignatureWallet.keyStore.getPublicKey(
              WalletUtility.getAccountIndexFromDerivationPath(
                  tx.changeAddressDerivationPath!),
              isChange: WalletUtility.isChangeFromDerivationPath(
                  tx.changeAddressDerivationPath!));
          String fingerPrint = singleSignatureWallet.keyStore.masterFingerprint;

          outputData[bip32DerivationKeyType + publicKey] = fingerPrint +
              Codec.encodeHex(
                  _serializeDerivationPath(tx.changeAddressDerivationPath!));
        } else if (wallet is MultisignatureWalletBase) {
          if (wallet.addressType == AddressType.p2wsh) {
            outputData[getKeyType(outputKeyType, 'WITNESS_SCRIPT')] =
                multisignatureWallet
                    .getWitnessScript(tx.changeAddressDerivationPath!);
          }
          for (KeyStore keyStore in multisignatureWallet.keyStoreList) {
            String publicKey = keyStore.getPublicKey(
                WalletUtility.getAccountIndexFromDerivationPath(
                    tx.changeAddressDerivationPath!),
                isChange: WalletUtility.isChangeFromDerivationPath(
                    tx.changeAddressDerivationPath!));

            String fingerPrint = keyStore.masterFingerprint;
            outputData[bip32DerivationKeyType + publicKey] = fingerPrint +
                Codec.encodeHex(
                    _serializeDerivationPath(tx.changeAddressDerivationPath!));
          }
        } else if (wallet is TaprootWalletBase) {
          final String derivationPath = tx.outputs[i].derivationPath!;
          final int addressIndex =
              WalletUtility.getAccountIndexFromDerivationPath(derivationPath);
          final bool isChange =
              WalletUtility.isChangeFromDerivationPath(derivationPath);
          final Map<String, KeyStore> keyStoresByPublicKey =
              <String, KeyStore>{};
          final Map<String, List<String>> leafHashesByPublicKey =
              <String, List<String>>{};

          for (KeyStore keyStore in taprootWallet.keyStoreList) {
            final String xOnlyPublicKey = keyStore.getPublicKey(addressIndex,
                isChange: isChange, isXOnly: true);
            keyStoresByPublicKey[xOnlyPublicKey] = keyStore;
            leafHashesByPublicKey.putIfAbsent(xOnlyPublicKey, () => <String>[]);
          }

          for (final Policy policy in taprootWallet.policyList) {
            if (policy is! InheritancePolicy) continue;
            final KeyStore keyStore = policy.beneficiaryKeyStore;
            final String xOnlyPublicKey = keyStore.getPublicKey(addressIndex,
                isChange: isChange, isXOnly: true);
            keyStoresByPublicKey[xOnlyPublicKey] = keyStore;
            leafHashesByPublicKey
                .putIfAbsent(xOnlyPublicKey, () => <String>[])
                .add(Codec.encodeHex(
                    policy.getTapleafHash(addressIndex, isChange: isChange)));
          }

          final String tapBip32DerivationKeyType =
              getKeyType(outputKeyType, 'TAP_BIP32_DERIVATION');
          for (final MapEntry<String, KeyStore> entry
              in keyStoresByPublicKey.entries) {
            final List<String> leafHashes = leafHashesByPublicKey[entry.key]!;
            outputData[tapBip32DerivationKeyType + entry.key] =
                '${Codec.encodeHex(Codec.encodeVariableInteger(leafHashes.length))}'
                '${leafHashes.join()}'
                '${entry.value.masterFingerprint}'
                '${Codec.encodeHex(_serializeDerivationPath(derivationPath))}';
          }
        }
      }

      psbtData["outputs"].add(outputData);
    }

    Psbt psbt = Psbt(psbtData);

    //check input amount is enough
    // int totalInputAmount = 0;
    // for (PsbtInput input in psbt.inputs) {
    //   totalInputAmount += input.witnessUtxo!.amount;
    // }
    // int totalOutputAmount = 0;
    // for (PsbtOutput output in psbt.outputs) {
    //   totalOutputAmount += output.outAmount!;
    // }
    // if (totalOutputAmount > totalInputAmount) {
    //   throw Exception('Not enough input amount');
    // }

    return psbt;
  }

  factory Psbt.fromMap(Map<String, dynamic> keyMap) {
    return Psbt(keyMap);
  }

  /// Parse a PSBT from a base64 string.
  factory Psbt.parse(String psbtBase64) {
    int offset = 0;

    Uint8List psbtBytes = base64Decode(psbtBase64);
    final version = psbtBytes.sublist(0, 5);
    if (version[0] != 0x70 ||
        version[1] != 0x73 ||
        version[2] != 0x62 ||
        version[3] != 0x74 ||
        version[4] != 0xff) {
      throw Exception('Invalid PSBT');
    }
    offset += 5;

    Map<String, dynamic> psbtData = {"global": {}, "inputs": [], "outputs": []};

    // Global
    Map<String, String> globalMap = {};
    // print(' ---> GLOBAL ---');
    while (true) {
      int keyLen = Codec.decodeVariableInteger(psbtBytes, offset);
      offset += Codec.getVariableIntegerLength(psbtBytes, offset);
      if (keyLen == 0) {
        break;
      }
      Uint8List key = psbtBytes.sublist(offset, offset + keyLen);
      offset += keyLen;
      int valueLen = Codec.decodeVariableInteger(psbtBytes, offset);
      offset += Codec.getVariableIntegerLength(psbtBytes, offset);
      Uint8List value = psbtBytes.sublist(offset, offset + valueLen);
      offset += valueLen;
      globalMap[Codec.encodeHex(key)] = Codec.encodeHex(value);
    }
    psbtData["global"] = globalMap;

    // Inputs
    if (psbtData["global"]["00"] == null) {
      throw Exception('Invalid PSBT');
    }
    Transaction globalTx =
        Transaction.parseUnsignedTransaction(psbtData["global"]["00"]);

    for (int i = 0; i < globalTx.inputs.length; i++) {
      Map<String, String> inputData = {};
      while (true) {
        int keyLen = Codec.decodeVariableInteger(psbtBytes, offset);
        offset += Codec.getVariableIntegerLength(psbtBytes, offset);
        if (keyLen == 0) {
          break;
        }
        Uint8List key = psbtBytes.sublist(offset, offset + keyLen);
        offset += keyLen;
        int valueLen = Codec.decodeVariableInteger(psbtBytes, offset);
        offset += Codec.getVariableIntegerLength(psbtBytes, offset);
        Uint8List value = psbtBytes.sublist(offset, offset + valueLen);
        offset += valueLen;
        inputData[Codec.encodeHex(key)] = Codec.encodeHex(value);
      }
      psbtData["inputs"].add(inputData);
    }

    // Outputs
    for (int i = 0; i < globalTx.outputs.length; i++) {
      Map<String, String> outputData = {};
      while (true) {
        int keyLen = Codec.decodeVariableInteger(psbtBytes, offset);
        // print(' -key len ${keyLen.toString()}-');
        offset += Codec.getVariableIntegerLength(psbtBytes, offset);
        if (keyLen == 0) {
          break;
        }
        Uint8List key = psbtBytes.sublist(offset, offset + keyLen);
        offset += keyLen;
        int valueLen = Codec.decodeVariableInteger(psbtBytes, offset);
        offset += Codec.getVariableIntegerLength(psbtBytes, offset);
        Uint8List value = psbtBytes.sublist(offset, offset + valueLen);
        offset += valueLen;
        outputData[Codec.encodeHex(key)] = Codec.encodeHex(value);
      }
      psbtData["outputs"].add(outputData);
    }

    return Psbt(psbtData);
  }

  String getAggregatedPublicNonce(int inputIndex) {
    return inputs[inputIndex].getAggregatedPublicNonce();
  }

  static List<String> _parseScriptWitness(String witnessHex) {
    Uint8List witnessBytes = Codec.decodeHex(witnessHex);
    int offset = 0;
    int numItems = Codec.decodeVariableInteger(witnessBytes, offset);
    offset += Codec.getVariableIntegerLength(witnessBytes, offset);

    List<String> witnessList = [];
    for (int j = 0; j < numItems; j++) {
      int itemLen = Codec.decodeVariableInteger(witnessBytes, offset);
      offset += Codec.getVariableIntegerLength(witnessBytes, offset);
      if (itemLen == 0) {
        witnessList.add('00');
      } else {
        witnessList.add(
            Codec.encodeHex(witnessBytes.sublist(offset, offset + itemLen)));
        offset += itemLen;
      }
    }
    return witnessList;
  }

  /// @nodoc
  static String getKeyType(Map<int, String> keyTypeMap, String typeName) {
    for (int key in keyTypeMap.keys) {
      if (keyTypeMap[key] == typeName) {
        return Converter.decToHexWithPadding(key, 2);
      }
    }
    throw Exception('Invalid Key Type');
  }

  /// @nodoc
  static Uint8List _serializeDerivationPath(String derivationPath) {
    final path = derivationPath.split('/').sublist(1).map((e) {
      if (e.contains('\'')) {
        return int.parse(e.replaceAll('\'', '')) + 0x80000000;
      } else {
        return int.parse(e);
      }
    }).toList();

    List<int> serializedPath = [];

    for (var index in path) {
      serializedPath.addAll(Converter.intToLittleEndianBytes(index, 4));
    }
    return Uint8List.fromList(serializedPath);
  }

  /// Get the transaction if all inputs are signed.
  Transaction getSignedTransaction(AddressType addressType) {
    Transaction signedTransaction =
        Transaction.parseUnsignedTransaction(unsignedTransaction!.serialize());
    signedTransaction._isSegwit = addressType.isSegwit;
    //p2wsh multisig
    if (addressType == AddressType.p2wsh) {
      for (int i = 0; i < inputs.length; i++) {
        if (inputs[i].totalSigner < inputs[i].requiredSignature) {
          throw Exception('Not enough signatures');
        }
        signedTransaction.inputs[i].setSignature(
            addressType, inputs[i].partialSig!,
            witnessScript: inputs[i].witnessScript);

        if (inputs[i].witnessUtxo == null) {
          continue;
        }

        if (signedTransaction.validateEcdsa(i, inputs[i].witnessUtxo!,
            witnessScript: inputs[i].witnessScript!.rawSerialize())) {
          continue;
        } else {
          throw Exception('Invalid Signatures');
        }
      }
      //p2wpkh single signature
    } else if (addressType == AddressType.p2wpkh) {
      for (int i = 0; i < inputs.length; i++) {
        // ignore: prefer_is_empty
        if (inputs[i].partialSig != null && inputs[i].partialSig?.length != 0) {
          signedTransaction.inputs[i]
              .setSignature(addressType, inputs[i].partialSig!);
          if (inputs[i].witnessUtxo == null) {
            continue;
          }
          if (signedTransaction.validateEcdsa(i, inputs[i].witnessUtxo!)) {
            continue;
          } else {
            throw Exception('Invalid Signatures');
          }
        } else if (inputs[i].finalScriptWitness != null &&
            inputs[i].finalScriptWitness!.isNotEmpty) {
          signedTransaction.inputs[i].witnessList =
              List<String>.from(inputs[i].finalScriptWitness!);
          if (inputs[i].witnessUtxo == null) {
            continue;
          }
          if (signedTransaction.validateEcdsa(i, inputs[i].witnessUtxo!)) {
            continue;
          } else {
            throw Exception('Invalid Signatures');
          }
        } else {
          throw Exception('Not enough signatures');
        }
      }
    } else if (addressType == AddressType.p2tr) {
      List<TransactionOutput> utxoList = [];
      for (int i = 0; i < inputs.length; i++) {
        utxoList.add(inputs[i].witnessUtxo!);
      }
      for (int i = 0; i < inputs.length; i++) {
        if (inputs[i].tapScriptSig != null) {
          //Script path spending
          signedTransaction.inputs[i].setTaprootScriptPathSpendingSignature(
              inputs[i].tapScriptSig![0].signature,
              // Witness must contain raw tapscript bytes (no length prefix).
              inputs[i].tapLeafScript!.rawSerialize(),
              inputs[i].controlBlock!);
        } else if (inputs[i].tapScriptSig == null &&
            inputs[i].muSig2AggregatedPublicKey == null) {
          // key path spending
          signedTransaction.inputs[i]
              .setTaprootKeyPathSpendingSignature(inputs[i].tapKeySig!);
          if (signedTransaction.validateSchnorr(i, utxoList)) {
            continue;
          } else {
            throw Exception('Invalid Signatures');
          }
        } else if (inputs[i].tapScriptSig == null &&
            inputs[i].muSig2AggregatedPublicKey != null) {
          //MuSig2
          if (inputs[i].totalSigner < inputs[i].requiredSignature) {
            throw Exception('Not enough signatures');
          }

          Uint8List aggregatedPubKey =
              Codec.decodeHex(inputs[i].muSig2AggregatedPublicKey!);
          Uint8List aggregatedPubNonce =
              Codec.decodeHex(inputs[i].getAggregatedPublicNonce());
          Uint8List message =
              Codec.decodeHex(signedTransaction.getTaprootSigHash(i, utxoList));

          SessionContext sessionContext = SessionContext(
            inputs[i]
                .muSig2ParticipantPubkeys!
                .map((e) => Codec.decodeHex(e))
                .toList(),
            aggregatedPubNonce,
            aggregatedPubKey,
            message,
            merkleRoot: (inputs[i].tapMerkleRoot != null &&
                    inputs[i].tapMerkleRoot!.isNotEmpty)
                ? Codec.decodeHex(inputs[i].tapMerkleRoot!)
                : null,
            applyTaprootTweak: true,
          );

          Uint8List aggregatedSignature = Ecc.getAggregatedSignatureForMuSig2(
              sessionContext, inputs[i].muSig2PartialSigs!);
          if (Ecc.verifySchnorr(
              message,
              Ecc.getEncoded(sessionContext.aggregateQ, true).sublist(1),
              aggregatedSignature)) {
            signedTransaction.inputs[i].setTaprootKeyPathSpendingSignature(
                Codec.encodeHex(aggregatedSignature));
          } else {
            throw Exception('Invalid Signatures');
          }
        }
      }
      if (!signedTransaction.validateSpend(utxoList)) {
        throw Exception('Invalid Transaction');
      }
    } else {
      throw Exception('Unsupported Address Type');
    }
    //Validate signedTransaction
    return signedTransaction;
  }

  bool validateSignature(int inputIndex, String signature, String publicKey) {
    String sigHash = _getSigHash(inputIndex);
    late bool isValid;
    if (addressType == null) {
      throw Exception('Address type is not set');
    }
    if (!addressType!.isTaproot) {
      // ECDSA
      isValid = Ecc.verifyEcdsa(
          Codec.decodeHex(sigHash),
          Codec.decodeHex(publicKey),
          Converter.derToRawSignature(Codec.decodeHex(signature)));
    } else {
      isValid = Ecc.verifySchnorr(
          Codec.decodeHex(sigHash),
          Codec.decodeHex(publicKey),
          Converter.derToRawSignature(Codec.decodeHex(signature)));
    }
    return isValid;
  }

  String _getSigHash(int inputIndex) {
    if (addressType == null) {
      throw Exception('Address type is not set');
    }

    late String sigHash;
    PsbtInput psbtInput = inputs[inputIndex];
    if (!addressType!.isTaproot) {
      // ECDSA
      TransactionOutput utxo = psbtInput.witnessUtxo!;
      if (addressType == AddressType.p2wsh) {
        String? witnessScript = psbtInput.witnessScript!.rawSerialize();
        sigHash = unsignedTransaction!.getSigHash(
            inputIndex, utxo, addressType!,
            witnessScript: witnessScript);
      } else {
        sigHash =
            unsignedTransaction!.getSigHash(inputIndex, utxo, addressType!);
      }
    } else {
      // Taproot
      List<TransactionOutput> utxoList = [];
      for (int j = 0; j < unsignedTransaction!.inputs.length; j++) {
        utxoList.add(inputs[j].witnessUtxo!);
      }
      sigHash = unsignedTransaction!.getTaprootSigHash(inputIndex, utxoList);
    }
    return sigHash;
  }

  bool isSigned(KeyStore keyStore, {isKeyPathSpending = false}) {
    for (PsbtInput input in inputs) {
      for (DerivationPath path in input.derivationPathList) {
        if (keyStore.masterFingerprint == path.masterFingerprint) {
          if (isKeyPathSpending) {
            return (input.tapKeySig != null);
          } else {
            String publicKey = keyStore.getPublicKey(
                WalletUtility.getAccountIndexFromDerivationPath(path.path),
                isChange: WalletUtility.isChangeFromDerivationPath(path.path),
                isXOnly: addressType!.isTaproot);
            // if (!input.signatureList
            //     .any((element) => element.publicKey == publicKey)) {
            //   return false;
            // }
            if (!addressType!.isTaproot) {
              if (input.signatureList.isEmpty) {
                return false;
              }
              for (Signature signature in input.signatureList) {
                if (signature.publicKey == publicKey) {
                  return true;
                }
              }
              return false;
            } else if (addressType == AddressType.p2tr) {
              if (input.muSig2PartialSigs == null) {
                return false;
              }
              for (Signature signature in input.muSig2PartialSigs!) {
                if (signature.publicKey.contains(publicKey)) {
                  return true;
                }
              }
              return false;
            }
          }
        }
      }
    }
    return false;
  }
}

/// @nodoc
class PsbtInput {
  //Field for Segwit v0
  TransactionOutput? witnessUtxo; //0x01
  List<Signature>? partialSig; //0x02
  List<DerivationPath>? bip32Derivation; //0x03
  MultisignatureScript? witnessScript; //0x05
  List<String>? finalScriptWitness; //0x08

  //Field for taproot
  String? internalKey; //0x17
  String? tapKeySig; //0x13(19)
  List<Signature>? tapScriptSig; //0x14(20)
  String? tapLeafHash; //0x16
  Script? tapLeafScript; //0x15
  String? controlBlock; //0x15
  List<DerivationPath>? tapBip32Derivation; //16
  String? tapMerkleRoot; //0x18

  PsbtInput.forKeyPathSpending(this.internalKey, this.witnessUtxo,
      this.tapBip32Derivation, this.tapKeySig,
      {this.tapMerkleRoot});

  String? muSig2AggregatedPublicKey; // 0x1a
  List<String>? muSig2ParticipantPubkeys; // 0x1a
  Map<String, String>? muSig2PubNonces; // 0x1b
  List<Signature>? muSig2PartialSigs; // 0x1c

  PsbtInput.forSegwit(this.witnessUtxo, this.bip32Derivation, this.partialSig,
      {this.witnessScript, this.tapKeySig});

  PsbtInput.forSignatureOnly(this.witnessUtxo, this.partialSig,
      {this.witnessScript});

  PsbtInput.forMuSig2(
      this.internalKey,
      this.witnessUtxo,
      this.tapBip32Derivation,
      this.muSig2AggregatedPublicKey,
      this.muSig2ParticipantPubkeys,
      this.muSig2PubNonces,
      this.muSig2PartialSigs,
      this.tapMerkleRoot);

  PsbtInput.forScriptPathSpending(
      this.internalKey,
      this.witnessUtxo,
      this.tapBip32Derivation,
      this.tapLeafHash,
      this.tapLeafScript,
      this.controlBlock,
      this.tapMerkleRoot);

  List<DerivationPath> get derivationPathList =>
      bip32Derivation == null ? tapBip32Derivation! : bip32Derivation!;
  List<Signature> get signatureList => {
        if (partialSig != null) ...partialSig!,
        if (tapScriptSig != null) ...tapScriptSig!,
        if (tapKeySig != null) ...[Signature(tapKeySig!, '')]
      }.toList();

  int get requiredSignature {
    if (muSig2ParticipantPubkeys != null) {
      return muSig2ParticipantPubkeys!.length;
    } else if (witnessScript == null) {
      return 1;
    } else {
      return witnessScript!.getRequiredSignature();
    }
  }

  int get totalSigner {
    return derivationPathList.length;
  }

  int get signedCount {
    if (tapScriptSig != null) {
      return tapScriptSig!.length;
    } else if (partialSig != null) {
      return partialSig!.length;
    }
    return 0;
  }

  addPartialSig(String signature, String publicKey) {
    // check if the public key is in the bip32 derivation list
    if (bip32Derivation != null) {
      if (!bip32Derivation!.any((element) => element.publicKey == publicKey)) {
        throw Exception('Public key not in PSBT input');
      }
    }
    partialSig!.add(Signature(signature, publicKey));
  }

  addTapKeySig(String signature) {
    tapKeySig = signature;
  }

  addTapScriptSig(String signature, String publicKey) {
    tapScriptSig ??= [];
    tapScriptSig!.add(Signature(signature, publicKey));
  }

  addMuSig2PubNonce(String publicKey, String aggregatedPublicKey,
      String sigHash, String publicNonce) {
    muSig2PubNonces ??= {};
    muSig2PubNonces!["$publicKey$aggregatedPublicKey$sigHash"] = publicNonce;
  }

  addMuSig2PartialSig(
    String signature,
    String publicKey,
    String aggregatedPublicKey,
    String sigHash,
  ) {
    muSig2PartialSigs ??= [];
    muSig2PartialSigs!
        .add(Signature(signature, "$publicKey$aggregatedPublicKey$sigHash"));
  }

  String getAggregatedPublicNonce() {
    // Check if we have any public nonces
    if (muSig2PubNonces == null || muSig2PubNonces!.isEmpty) {
      throw Exception('No MuSig2 public nonces found');
    }

    // Get all public nonces
    List<Uint8List> publicNonces =
        muSig2PubNonces!.values.map((hex) => Codec.decodeHex(hex)).toList();
    // print('publicNonces: ${publicNonces.map((e) => Codec.encodeHex(e))}');

    if (publicNonces.isEmpty) {
      throw Exception('No public nonces found');
    }
    // print(
    //     'aggregatePublicNonce: ${Codec.encodeHex(aggregatePublicNonce(publicNonces))}');
    return Codec.encodeHex(aggregatePublicNonce(publicNonces));
  }

  static Uint8List aggregatePublicNonce(List<Uint8List> publicNonces) {
    if (publicNonces.isEmpty) {
      throw ArgumentError('At least one public nonce required');
    }
    if (publicNonces[0].length != 66) {
      throw ArgumentError('Public nonce #0 must be 66 bytes');
    }

    Uint8List r1 = publicNonces[0].sublist(0, 33);
    Uint8List r2 = publicNonces[0].sublist(33, 66);

    for (int i = 1; i < publicNonces.length; i++) {
      final nonce = publicNonces[i];
      if (nonce.length != 66) {
        throw ArgumentError('Public nonce #$i must be 66 bytes');
      }

      final r1i = nonce.sublist(0, 33);
      final r2i = nonce.sublist(33, 66);

      r1 = Ecc.pointCombine(r1, r1i, true) ?? Uint8List(33);
      r2 = Ecc.pointCombine(r2, r2i, true) ?? Uint8List(33);
    }

    return Uint8List.fromList([...r1, ...r2]);
  }
}

/// @nodoc
class PsbtOutput {
  final List<DerivationPath> bip32Derivations; //0x02
  final List<DerivationPath> tapBip32Derivations; //0x07
  final int? outAmount; //0x03
  final ScriptPublicKey? outScript; //0x04
  MultisignatureScript? witnessScript; //0x01

  PsbtOutput(
      List<DerivationPath> bip32Derivations, this.outAmount, this.outScript,
      {List<DerivationPath> tapBip32Derivations = const [], this.witnessScript})
      : bip32Derivations = List.unmodifiable(bip32Derivations),
        tapBip32Derivations = List.unmodifiable(tapBip32Derivations);

  String get outAddress => outScript!.getAddress();

  /// Returns whether this output is verified as change for [wallet].
  bool isChange(WalletBase wallet) {
    final List<String> derivationPaths = wallet.addressType.isTaproot
        ? tapBip32Derivations.map((derivation) => derivation.path).toList()
        : bip32Derivations.map((derivation) => derivation.path).toList();
    return isOwnedBy(wallet) &&
        derivationPaths.isNotEmpty &&
        derivationPaths.every(WalletUtility.isChangeFromDerivationPath);
  }

  /// Returns whether this output belongs to [wallet].
  bool isOwnedBy(WalletBase wallet) {
    final List<String> derivationPaths = wallet.addressType.isTaproot
        ? tapBip32Derivations.map((derivation) => derivation.path).toList()
        : bip32Derivations.map((derivation) => derivation.path).toList();
    if (outScript == null || derivationPaths.isEmpty) {
      return false;
    }

    final List<String> walletPathSegments = wallet.derivationPath.split('/');

    for (final String path in derivationPaths) {
      final List<String> pathSegments = path.split('/');
      final bool isDirectAddressPath = pathSegments.length ==
              walletPathSegments.length + 2 &&
          pathSegments
              .sublist(0, walletPathSegments.length)
              .asMap()
              .entries
              .every((entry) => entry.value == walletPathSegments[entry.key]) &&
          (pathSegments[pathSegments.length - 2] == '0' ||
              pathSegments[pathSegments.length - 2] == '1') &&
          int.tryParse(pathSegments.last) != null;

      if (!isDirectAddressPath || !WalletUtility.validateDerivationPath(path)) {
        continue;
      }

      try {
        if (wallet.getAddressWithDerivationPath(path) == outAddress) {
          return true;
        }
      } catch (_) {
        continue;
      }
    }

    return false;
  }
}

/// @nodoc
class DerivationPath {
  final String _publicKey;
  final String _masterFingerprint;
  final String _path;
  final List<String> _leafHashes;

  DerivationPath(this._publicKey, this._masterFingerprint, this._path,
      {List<String> leafHashes = const []})
      : _leafHashes = List.unmodifiable(leafHashes);

  factory DerivationPath.fromBip32(String publicKey, String value) {
    final Uint8List valueBytes = Codec.decodeHex(value);
    if (valueBytes.length < 4 || (valueBytes.length - 4) % 4 != 0) {
      throw const FormatException('Invalid BIP32_DERIVATION value');
    }

    final String masterFingerprint = Codec.encodeHex(valueBytes.sublist(0, 4));
    final String path = _parsePath(valueBytes.sublist(4));
    return DerivationPath(publicKey, masterFingerprint, path);
  }

  factory DerivationPath.fromTaproot(String xOnlyPublicKey, String value) {
    if (xOnlyPublicKey.length != 64) {
      throw const FormatException(
          'TAP_BIP32_DERIVATION requires a 32-byte X-only key');
    }

    final Uint8List valueBytes = Codec.decodeHex(value);
    if (valueBytes.isEmpty) {
      throw const FormatException('TAP_BIP32_DERIVATION value is empty');
    }

    int offset = Codec.getVariableIntegerLength(valueBytes, 0);
    if (valueBytes.length < offset) {
      throw const FormatException('Invalid TAP_BIP32_DERIVATION CompactSize');
    }
    final int leafHashCount = Codec.decodeVariableInteger(valueBytes, 0);
    final int metadataLength = leafHashCount * 32 + 4;
    if (valueBytes.length < offset + metadataLength ||
        (valueBytes.length - offset - metadataLength) % 4 != 0) {
      throw const FormatException('Invalid TAP_BIP32_DERIVATION value');
    }

    final List<String> leafHashes = <String>[];
    for (int i = 0; i < leafHashCount; i++) {
      leafHashes.add(Codec.encodeHex(valueBytes.sublist(offset, offset + 32)));
      offset += 32;
    }

    final String masterFingerprint =
        Codec.encodeHex(valueBytes.sublist(offset, offset + 4));
    offset += 4;
    final String path = _parsePath(valueBytes.sublist(offset));
    return DerivationPath(xOnlyPublicKey, masterFingerprint, path,
        leafHashes: leafHashes);
  }

  static String _parsePath(Uint8List serializedPath) {
    if (serializedPath.length % 4 != 0) {
      throw const FormatException(
          'Serialized derivation path length must be a multiple of 4');
    }

    final List<String> pathSegments = <String>['m'];
    for (int i = 0; i < serializedPath.length; i += 4) {
      int value = Converter.littleEndianToInt(serializedPath.sublist(i, i + 4));
      if (value & 0x80000000 != 0) {
        value &= ~0x80000000;
        pathSegments.add('$value\'');
      } else {
        pathSegments.add('$value');
      }
    }
    return pathSegments.join('/');
  }

  String get publicKey => _publicKey;
  String get masterFingerprint => _masterFingerprint.toUpperCase();
  String get path => _path;
  List<String> get leafHashes => _leafHashes;
  int get accountIndex {
    return WalletUtility.getAccountIndexFromDerivationPath(_path);
  }

  bool get isChange {
    return WalletUtility.isChangeFromDerivationPath(_path);
  }
}
