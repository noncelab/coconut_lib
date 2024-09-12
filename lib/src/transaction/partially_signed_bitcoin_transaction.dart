part of '../../coconut_lib.dart';

/// Represents a PSBT(BIP-0174).
class PSBT {
  /// @nodoc
  Map<String, dynamic> psbtMap;

  /// Get transaction not signed yet.
  Transaction? unsignedTransaction;

  /// @nodoc
  List<PsbtInput> inputs = [];

  /// @nodoc
  List<PsbtOutput> outputs = [];

  /// @nodoc
  DerivationPath? derivationPath;

  /// Get the fee of the transaction.
  int get fee => () {
        int totalInput = 0;
        int totalOutput = 0;
        for (int i = 0; i < inputs.length; i++) {
          totalInput += inputs[i].witnessUtxo!.amount;
        }
        for (int i = 0; i < unsignedTransaction!.outputs.length; i++) {
          totalOutput += unsignedTransaction!.outputs[i].amount;
        }
        return totalInput - totalOutput;
      }();

  /// Get the sending amount of the transaction.
  int get sendingAmount => () {
        int sendingAmount = 0;
        for (PsbtOutput output in outputs) {
          if (output.derivationPath != null && output.isChange) continue;
          sendingAmount += output.amount!;
        }

        return sendingAmount;
      }();

  /// @nodoc
  PSBT(this.psbtMap) {
    unsignedTransaction =
        Transaction.parseUnsignedTransaction(psbtMap["global"]["00"]);

    psbtMap["global"].keys.forEach((key) {
      if (key.startsWith('01')) {
        String publicKey = key.substring(2);
        String parentFingerprint = psbtMap["global"][key].substring(0, 8);
        String derivationPath = _parseDerivationPath(
            Converter.hexToBytes(psbtMap["global"][key].substring(8)));
        this.derivationPath =
            DerivationPath(publicKey, parentFingerprint, derivationPath);
      }
    });

    for (int i = 0; i < psbtMap["inputs"].length; i++) {
      // print(psbtMap["inputs"][i]["00"]);
      Transaction? prevTx;
      if (psbtMap["inputs"][i].containsKey("00")) {
        //print(psbtMap["inputs"][i]["00"]);
        prevTx = Transaction.parse(psbtMap["inputs"][i]["00"]);
      }
      TransactionOutput? witnessUtxo;
      if (psbtMap["inputs"][i].containsKey("01")) {
        witnessUtxo = TransactionOutput.parse(psbtMap["inputs"][i]["01"]);
      }

      DerivationPath? inputDerivationPath;
      List<String> partialSigs = [];
      psbtMap["inputs"][i].keys.forEach((key) {
        if (key.startsWith('06')) {
          String publicKey = key.substring(2);
          String parentFingerprint = psbtMap["inputs"][i][key].substring(0, 8);
          String derivationPath = _parseDerivationPath(
              Converter.hexToBytes(psbtMap["inputs"][i][key].substring(8)));
          inputDerivationPath =
              DerivationPath(publicKey, parentFingerprint, derivationPath);
        }
        if (key.startsWith('02')) {
          String publicKey = key.substring(2);
          String signature = psbtMap["inputs"][i][key];
          partialSigs.add(signature);
          partialSigs.add(publicKey);
        }
      });
      inputs.add(
          PsbtInput(prevTx, witnessUtxo, inputDerivationPath, partialSigs));
    }

    for (int i = 0; i < psbtMap["outputs"].length; i++) {
      int? amount;
      String? script;
      if (psbtMap["outputs"][i].containsKey("03")) {
        //print(psbtMap["inputs"][i]["00"]);
        amount = Converter.littleEndianToInt(
            Converter.hexToBytes(psbtMap["outputs"][i]["03"]));
      }

      if (psbtMap["outputs"][i].containsKey("04")) {
        script = psbtMap["outputs"][i]["04"];
      }

      DerivationPath? outputDerivationPath;
      psbtMap["outputs"][i].keys.forEach((key) {
        if (key.startsWith('02')) {
          String publicKey = key.substring(2);
          String parentFingerprint = psbtMap["outputs"][i][key].substring(0, 8);
          String derivationPath = _parseDerivationPath(
              Converter.hexToBytes(psbtMap["outputs"][i][key].substring(8)));
          outputDerivationPath =
              DerivationPath(publicKey, parentFingerprint, derivationPath);
        }
      });
      outputs.add(PsbtOutput(outputDerivationPath, amount, script));
    }
  }

  /// Generate the PSBT to base64 string.
  String serialize() {
    List<int> psbtBytes = [0x70, 0x73, 0x62, 0x74, 0xff];
    //Global
    psbtBytes.addAll(_serializeKeyMap(psbtMap["global"]));
    psbtBytes.add(0x00);
    List<dynamic> inputList = psbtMap["inputs"];
    // print(inputList.length);
    for (int i = 0; i < inputList.length; i++) {
      psbtBytes.addAll(_serializeKeyMap(inputList[i]));
      psbtBytes.add(0x00);
    }
    //psbtBytes.add(0x00);
    List<dynamic> outputList = psbtMap["outputs"];
    for (int i = 0; i < outputList.length; i++) {
      psbtBytes.addAll(_serializeKeyMap(outputList[i]));
      psbtBytes.add(0x00);
    }

    psbtBytes.add(0x00);
    return base64Encode(psbtBytes);
  }

  List<int> _serializeKeyMap(Map<String, dynamic> map) {
    List<int> globalBytes = [];
    map.forEach((key, value) {
      List<int> keyBytes = Converter.hexToBytes(key);
      globalBytes += Varints.encode(keyBytes.length);
      globalBytes += keyBytes;
      List<int> valueBytes = Converter.hexToBytes(value);
      globalBytes += Varints.encode(valueBytes.length);
      globalBytes += valueBytes;
    });
    return globalBytes;
  }

  /// Create a PSBT for sending bitcoin.
  factory PSBT.forSending(
      String address, int amount, int feeRate, WalletBase wallet) {
    List<UtxoEntity> selectedUtxos = _selectOptimalUtxo(
        Repository()._getUtxoEntityList(wallet.identifier),
        amount,
        feeRate,
        wallet.addressType);

    int totalInputAmount = 0;
    List<TransactionInput> inputs = [];
    List<TransactionOutput> outputs = [];
    for (UtxoEntity utxo in selectedUtxos) {
      totalInputAmount += utxo.amount;
      inputs.add(TransactionInput.forSending(utxo.txHash, utxo.index));
    }
    int fee = _calculateEstimationFee(
        selectedUtxos.length, 2, feeRate, wallet.addressType);

    int change = totalInputAmount - amount - fee;
    String changeAddress;
    if (wallet is SingleSignatureWallet) {
      changeAddress = wallet.getChangeAddress().address;
    } else if (wallet is MultisignatureWallet) {
      changeAddress = wallet.getChangeAddress().address;
    } else {
      throw Exception('Invalid Wallet Type');
    }

    TransactionOutput sendingOutput =
        TransactionOutput.forSending(amount, address);
    TransactionOutput changeOutput =
        TransactionOutput.forSending(change, changeAddress);

    outputs.add(sendingOutput);
    outputs.add(changeOutput);
    Transaction tx = Transaction.forSending(inputs, outputs, true);

    //minimum fee check
    if (tx.getVirtualByte() > fee) {
      change = totalInputAmount - amount - tx.getVirtualByte().ceil();
      changeOutput.setAmount(change);
    }

    return PSBT.fromTransaction(tx, wallet);
  }

  /// Create a PSBT for sending all bitcoin in the wallet.
  factory PSBT.forMaximumSending(
      String address, int feeRate, WalletBase wallet) {
    List<TransactionInput> inputs = [];
    int inputAmount = 0;
    for (UtxoEntity utxo
        in Repository()._getUtxoEntityList(wallet.identifier)) {
      if (utxo.height == 0) {
        continue;
      }
      inputs.add(TransactionInput.forSending(utxo.txHash, utxo.index));
      inputAmount += utxo.amount;
    }

    Transaction tx = Transaction.forMaximumSending(
        inputs, address, inputAmount, wallet.addressType.isSegwit, feeRate);
    // print(tx.serialize());
    return PSBT.fromTransaction(tx, wallet);
  }

  static int _calculateEstimationFee(int numberOfInput, int numberOfOutput,
      int feeRate, AddressType addressType) {
    int baseByte = 10;
    int perOutputByte = 0;
    int perInputByte = 0;

    if (addressType == AddressType.p2pkh) {
      perOutputByte = 34;
      perInputByte = 148;
    } else if (addressType == AddressType.p2wpkh) {
      perOutputByte = 31;
      perInputByte = 68;
      baseByte += 2;
    } else if (addressType == AddressType.p2sh) {
      perOutputByte = 32;
      perInputByte = 91;
    }
    // else if(addressType == AddressType.p2wsh){
    //   perOutputByte = 43;
    //   perInputByte = 68;
    // baseByte += 2;
    // }
    int totalByte = baseByte +
        perOutputByte * numberOfOutput +
        perInputByte * numberOfInput;
    // print("totalByte : $totalByte");
    return totalByte * feeRate;
  }

  static List<UtxoEntity> _selectOptimalUtxo(List<UtxoEntity> utxos, int amount,
      int feeRate, AddressType addressType) {
    int baseVbyte = 72; //0 input, 2 output
    int vBytePerInput = 0;
    if (addressType.isSegwit) {
      vBytePerInput = 68; //segwit discount
    } else {
      vBytePerInput = 148;
    }
    List<UtxoEntity> selectedUtxos = [];

    int totalAmount = 0;
    int totalVbyte = baseVbyte;
    int finalFee = 0;
    utxos.sort((a, b) => b.amount.compareTo(a.amount));
    for (UtxoEntity utxo in utxos) {
      if (utxo.height == 0) {
        continue;
      }
      selectedUtxos.add(utxo);
      totalAmount += utxo.amount;
      totalVbyte += vBytePerInput;
      int fee = totalVbyte * feeRate;
      if (totalAmount >= amount + fee) {
        return selectedUtxos;
      }
      finalFee = fee;
    }
    throw Exception('Not enough amount for sending. (Fee : $finalFee)');
  }

  /// Create a PSBT from a Transaction object.
  factory PSBT.fromTransaction(Transaction tx, WalletBase wallet) {
    Map<String, dynamic> psbtData = {"global": {}, "inputs": [], "outputs": []};

    //--- Global
    Map<String, dynamic> globalData = {};
    //Tx
    String txKey = getKeyType(globalKeyType, 'UNSIGNED_TX');
    globalData[txKey] = tx.serializeLegacy(); //old serialze format BIP0174
    //Xpub
    String xpubKeyType = getKeyType(globalKeyType, 'XPUB');

    if (wallet is SingleSignatureWallet) {
      String xpub =
          Converter.bytesToHex(wallet.keyStore.extendedPublicKey.publicKey);
      String xpubKey = xpubKeyType + xpub;
      String xpubValue = Converter.bytesToHex(
          wallet.keyStore.extendedPublicKey.parentFingerprintByte +
              _serializeDerivationPath(wallet.derivationPath));
      globalData[xpubKey] = xpubValue;
    } else if (wallet is MultisignatureWallet) {
      for (int i = 0; i < wallet.totalSigner; i++) {
        String xpub = Converter.bytesToHex(
            wallet.keyStoreList[i]._extendedPublicKey.publicKey);
        String xpubKey = xpubKeyType + xpub;
        //print(wallet.derivationPath);
        String xpubValue = Converter.bytesToHex(
            wallet.keyStoreList[i]._extendedPublicKey.parentFingerprintByte +
                _serializeDerivationPath(wallet.derivationPath));
        globalData[xpubKey] = xpubValue;
      }
    }
    // }
    // String xpub = Converter.bytesToHex(wallet._extendedPublicKey.publicKey);
    // String xpubKey = xpubKeyType + xpub;
    // //print(wallet.derivationPath);
    // String xpubValue = Converter.bytesToHex(
    //     wallet._extendedPublicKey.parentFingerprint +
    //         serializeDerivationPath(wallet.derivationPath));
    psbtData["global"] = globalData;

    //input
    for (int i = 0; i < tx.inputs.length; i++) {
      Map<String, dynamic> inputData = {};
      String prevTxHash = tx.inputs[i].transactionHash;
      int prevIndex = tx.inputs[i].index;

      Transaction prevTx = Repository()._getTransaction(prevTxHash);

      //TODO : doen't need NON_WITNESS_UTXO for sigle sig in segwit
      if (wallet.addressType.isMultisig || !wallet.addressType.isSegwit) {
        //  Transaction.parse(wallet.repository.getTransaction(prevTxHash));

        print("****************");
        print("MS:${wallet.addressType.isMultisig}");
        print("seg:${wallet.addressType.isSegwit}");

        String nonWitnessUtxoKey = getKeyType(inputKeyType, 'NON_WITNESS_UTXO');
        inputData[nonWitnessUtxoKey] = prevTx.serialize();
      }

      //if utxo is witness
      TransactionOutput utxo = prevTx.outputs[prevIndex];
      if (utxo.scriptPubKey.isP2WPKH() || utxo.scriptPubKey.isP2WSH()) {
        String witnessUtxoKey = getKeyType(inputKeyType, 'WITNESS_UTXO');
        inputData[witnessUtxoKey] = utxo.serialize();
      }

      //derivation path
      String bip32DerivationKeyType =
          getKeyType(inputKeyType, 'BIP32_DERIVATION');
      String address = utxo.scriptPubKey.getAddress();
      String derivationPath = wallet.addressBook.getDerivationPath(address);
      if (wallet is SingleSignatureWallet) {
        String publicKey =
            wallet.keyStore.getPublicKeyWithDerivationPath(derivationPath);
        String fingerPrint = wallet.keyStore.fingerprint;

        inputData[bip32DerivationKeyType + publicKey] = fingerPrint +
            Converter.bytesToHex(_serializeDerivationPath(derivationPath));
      } else if (wallet is MultisignatureWallet) {
        for (int i = 0; i < wallet.totalSigner; i++) {
          String publicKey = wallet.keyStoreList[i]
              .getPublicKeyWithDerivationPath(derivationPath);
          String fingerPrint = wallet.keyStoreList[i].fingerprint;

          inputData[bip32DerivationKeyType + publicKey] = fingerPrint +
              Converter.bytesToHex(_serializeDerivationPath(derivationPath));
        }
      }
      if (tx.inputs[i].witnessList.isNotEmpty) {
        String partialSigKeyType = getKeyType(inputKeyType, 'PARTIAL_SIG');
        String publicKey = tx.inputs[i].witnessList[0];
        String signature = tx.inputs[i].witnessList[1];
        inputData[partialSigKeyType + publicKey] = signature;
      }
      psbtData["inputs"].add(inputData);
    }

    //output
    for (int i = 0; i < tx.outputs.length; i++) {
      Map<String, dynamic> outputData = {};
      String amountKey = getKeyType(outputKeyType, 'AMOUNT');
      outputData[amountKey] = Converter.bytesToHex(
          Converter.intToLittleEndianBytes(tx.outputs[i].amount, 4));
      String scriptKey = getKeyType(outputKeyType, 'SCRIPT');
      outputData[scriptKey] = tx.outputs[i].scriptPubKey.serialize();
      String addr = tx.outputs[i].getAddress();
      // print(addr);
      if (wallet.addressBook.contains(addr)) {
        //print(addr);
        String bip32DerivationKeyType =
            getKeyType(outputKeyType, 'BIP32_DERIVATION'); //02
        String derivationPath = wallet.addressBook.getDerivationPath(addr);
        if (wallet is SingleSignatureWallet) {
          String publicKey =
              wallet.keyStore.getPublicKeyWithDerivationPath(derivationPath);
          String fingerPrint = wallet.keyStore.fingerprint;

          outputData[bip32DerivationKeyType + publicKey] = fingerPrint +
              Converter.bytesToHex(_serializeDerivationPath(derivationPath));
        } else if (wallet is MultisignatureWallet) {
          for (int i = 0; i < wallet.totalSigner; i++) {
            String publicKey = wallet.keyStoreList[i]
                .getPublicKeyWithDerivationPath(derivationPath);
            String fingerPrint = wallet.keyStoreList[i].fingerprint;

            outputData[bip32DerivationKeyType + publicKey] = fingerPrint +
                Converter.bytesToHex(_serializeDerivationPath(derivationPath));
          }
        }
        // String publicKey =
        //     wallet.getPublicKeyWithDerivationPath(derivationPath);
        // String fingerPrint = wallet.fingerprint;

        // outputData[bip32DerivationKeyType + publicKey] = fingerPrint +
        //     Converter.bytesToHex(serializeDerivationPath(derivationPath));
      }
      psbtData["outputs"].add(outputData);
    }
    return PSBT(psbtData);
  }

  /// Parse a PSBT from a base64 string.
  factory PSBT.parse(String psbtBase64) {
    int offset = 0;

    Uint8List psbtBytes = base64Decode(psbtBase64);
    // print('----HEX---- ${psbtBytes.length}----');
    // print(Converter.bytesToHex(psbtBytes));
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
      int keyLen = Varints.read(psbtBytes, offset);
      // print(' -key len ${keyLen.toString()}-');
      offset += _getOffset(psbtBytes[offset]);
      if (keyLen == 0) {
        break;
      }
      // int keyType = psbtBytes[offset];
      // print(
      //     ' -key type ${keyType.toString()}->${globalKeyType[keyType].toString()}');
      Uint8List key = psbtBytes.sublist(offset, offset + keyLen);
      offset += keyLen;
      int valueLen = Varints.read(psbtBytes, offset);
      // print(' -value len ${valueLen.toString()}-');
      offset += _getOffset(psbtBytes[offset]);
      Uint8List value = psbtBytes.sublist(offset, offset + valueLen);
      // print('-vaule : ' + Converter.bytesToHex(value));
      offset += valueLen;
      globalMap[Converter.bytesToHex(key)] = Converter.bytesToHex(value);
    }
    psbtData["global"] = globalMap;
    // Inputs

    // print(' ---> INPUT ---');
    if (psbtData["global"]["00"] == null) {
      throw Exception('Invalid PSBT');
    }
    Transaction globalTx =
        Transaction.parseUnsignedTransaction(psbtData["global"]["00"]);

    for (int i = 0; i < globalTx.inputs.length; i++) {
      Map<String, String> inputData = {};
      while (true) {
        int keyLen = Varints.read(psbtBytes, offset);
        // print(' -key len ${keyLen.toString()}-');
        offset += _getOffset(psbtBytes[offset]);
        if (keyLen == 0) {
          break;
        }
        // int keyType = psbtBytes[offset];
        // print(
        //     ' -key type ${keyType.toString()}->${inputKeyType[keyType].toString()}');
        Uint8List key = psbtBytes.sublist(offset, offset + keyLen);
        // print("- key data : " + Converter.bytesToHex(key));
        offset += keyLen;
        int valueLen = Varints.read(psbtBytes, offset);
        // print("- valueLen : " + valueLen.toString());
        offset += _getOffset(psbtBytes[offset]);
        Uint8List value = psbtBytes.sublist(offset, offset + valueLen);
        // print('->vaule : ' + Converter.bytesToHex(value));
        offset += valueLen;
        inputData[Converter.bytesToHex(key)] = Converter.bytesToHex(value);
      }
      psbtData["inputs"].add(inputData);
    }
    // Outputs
    // print(' ---> OUTPUT ---');

    for (int i = 0; i < globalTx.outputs.length; i++) {
      Map<String, String> outputData = {};
      while (true) {
        int keyLen = Varints.read(psbtBytes, offset);
        // print(' -key len ${keyLen.toString()}-');
        offset += _getOffset(psbtBytes[offset]);
        if (keyLen == 0) {
          break;
        }
        // int keyType = psbtBytes[offset];
        // print(
        //     ' -key type ${keyType.toString()}->${outputKeyType[keyType].toString()}');
        Uint8List key = psbtBytes.sublist(offset, offset + keyLen);
        offset += keyLen;
        int valueLen = Varints.read(psbtBytes, offset);
        // print("- valueLen : " + valueLen.toString());
        offset += _getOffset(psbtBytes[offset]);
        Uint8List value = psbtBytes.sublist(offset, offset + valueLen);
        // print('->vaule : ' + Converter.bytesToHex(value));
        offset += valueLen;
        outputData[Converter.bytesToHex(key)] = Converter.bytesToHex(value);
      }
      psbtData["outputs"].add(outputData);
    }

    return PSBT(psbtData);
  }

  /// @nodoc
  PsbtInput getPsbtInput(String txHash) {
    return inputs.firstWhere(
        (element) => element.previousTransaction!.transactionHash == txHash);
  }

  /// Add a signature to the PSBT.
  void addSignature(int inputIndex, String signature, String publicKey) {
    inputs[inputIndex]._addSignature(signature, publicKey);
    psbtMap["inputs"][inputIndex]["02$publicKey"] = signature;
  }

  /// @nodoc
  @override
  String toString() {
    return jsonEncode(psbtMap);
  }

  static int _getOffset(int prefix) {
    if (prefix == 0xfd) {
      return 3;
    } else if (prefix == 0xfe) {
      return 5;
    } else if (prefix == 0xff) {
      return 9;
    }
    return 1;
  }

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
    25: 'REQUIRED_HEIGHT_LOCKTIME',
    26: 'REQUIRED_HEIGHT_LOCKTIME',
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
    252: 'PROPRIETARY'
  };

  /// @nodoc
  static String getKeyType(Map<int, String> keyTypeMap, String typeName) {
    return Converter.decToHexWithPadding(
        globalKeyType.keys
            .firstWhere((element) => keyTypeMap[element] == typeName),
        2);
  }

  /// @nodoc
  static Uint8List _serializeDerivationPath(String derivationPath) {
    //print(derivationPath);
    final path = derivationPath.split('/').sublist(1).map((e) {
      //print(e);
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

  /// @nodoc
  static String _parseDerivationPath(Uint8List serializedPath) {
    if (serializedPath.length % 4 != 0) {
      throw ArgumentError('Serialized path length must be a multiple of 4');
    }

    List<String> pathSegments = ['m'];

    for (int i = 0; i < serializedPath.length; i += 4) {
      Uint8List valueBytes = serializedPath.sublist(i, i + 4);
      int value = Converter.littleEndianToInt(valueBytes);

      if (value & 0x80000000 != 0) {
        value &= ~0x80000000;
        pathSegments.add('$value\'');
      } else {
        pathSegments.add('$value');
      }
    }

    return pathSegments.join('/');
  }

  /// Get the transaction if all inputs are signed.
  Transaction getSignedTransaction(AddressType addressType) {
    Transaction signedTransaction =
        Transaction.parseUnsignedTransaction(unsignedTransaction!.serialize());
    //every input should have 2 partial sigs
    for (int i = 0; i < inputs.length; i++) {
      if (inputs[i].partialSigs!.length != 2) {
        throw Exception('Not enough signatures');
      }
      signedTransaction.inputs[i].setSignature(
          addressType, inputs[i].partialSigs![0], inputs[i].partialSigs![1]);
      if (signedTransaction.validateSignature(
          i, inputs[i].witnessUtxo!.serialize(), addressType)) {
        continue;
      } else {
        throw Exception('Invalid Signatures');
      }
    }

    signedTransaction._isSegwit = addressType.isSegwit;
    // print("getsignedtransaction : ${signedTransaction.serialize()}");
    return signedTransaction;
  }

  /// Get estimated fee for the transaction.
  int estimateFee(int feeRate, AddressType addressType) {
    // print(unsignedTransaction!.serialize());
    return _calculateEstimationFee(unsignedTransaction!.inputs.length,
        unsignedTransaction!.outputs.length, feeRate, addressType);
  }
}

/// @nodoc
class PsbtInput {
  final Transaction? _previousTransaction;
  final TransactionOutput? _witnessUtxo;
  final DerivationPath? _derivationPath;
  final List<String> _partialSigs;

  Transaction? get previousTransaction => _previousTransaction;
  TransactionOutput? get witnessUtxo => _witnessUtxo;
  DerivationPath? get derivationPath => _derivationPath;
  List<String>? get partialSigs => _partialSigs;

  PsbtInput(this._previousTransaction, this._witnessUtxo, this._derivationPath,
      this._partialSigs);

  _addSignature(String signature, String publicKey) {
    _partialSigs.add(signature);
    _partialSigs.add(publicKey);
  }
}

/// @nodoc
class PsbtOutput {
  final DerivationPath? _derivationPath;
  final int? _amount;
  final String? _script;

  DerivationPath? get derivationPath => _derivationPath;
  int? get amount => _amount;
  String? get script => _script;

  String getAddress() {
    ScriptPublicKey script = ScriptPublicKey.parse(_script!);
    return script.getAddress();
  }

  /// @nodoc
  bool get isChange {
    if (derivationPath == null) {
      return false;
    } else if (derivationPath!.path.split('/')[4] == '1') {
      return true;
    } else {
      return false;
    }
  }

  PsbtOutput(this._derivationPath, this._amount, this._script);
}

/// @nodoc
class DerivationPath {
  final String _publicKey;
  final String _parentFingerprint;
  final String _path;

  DerivationPath(this._publicKey, this._parentFingerprint, this._path);

  String get publicKey => _publicKey;
  String get parentFingerprint => _parentFingerprint.toUpperCase();
  String get path => _path;
}
