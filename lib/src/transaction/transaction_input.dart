part of '../../coconut_lib.dart';

/// Represents a transaction input.
///
/// {@category Transactions}
class TransactionInput {
  Uint8List _transactionHash;
  Uint8List _index;

  /// Get the script signature of the transaction.
  late ScriptSignature scriptSig;
  late Uint8List _sequence;

  /// @nodoc
  late List<String> witnessList;

  /// Get the previous transaction hash.
  String get transactionHash =>
      Codec.encodeHex(_transactionHash.reversed.toList());

  /// Get the index of previous transaction.
  int get index => Converter.littleEndianToInt(_index);

  /// Get the sequence of the transaction.
  int get sequence => Converter.littleEndianToInt(_sequence);

  /// The length of the transaction input.
  int get length => () {
        int length = 0;
        length += _transactionHash.length;
        length += _index.length;
        length += scriptSig.length;
        length += _sequence.length;
        return length;
      }();

  /// @nodoc
  TransactionInput(
      this._transactionHash, this._index, this.scriptSig, this._sequence,
      {List<String>? witnessList})
      : witnessList =
            witnessList != null ? List<String>.from(witnessList) : <String>[];

  /// Parse the transaction input from the given input string.
  factory TransactionInput.parse(String input) {
    Uint8List bytes = Codec.decodeHex(input);
    if (bytes.length < 41) {
      throw const FormatException('Truncated transaction input.');
    }
    //print("full : " + Converter.bytesToHex(bytes));
    var txHash = bytes.sublist(0, 32);
    var index = bytes.sublist(32, 36);
    var scriptSize = 0;

    // coinbase transaction
    if (Codec.encodeHex(txHash) ==
            '0000000000000000000000000000000000000000000000000000000000000000' &&
        Codec.encodeHex(index) == 'ffffffff') {
      scriptSize = bytes[36];
      if (37 + scriptSize + 4 > bytes.length) {
        throw const FormatException('Truncated coinbase transaction input.');
      }
      var sequence =
          bytes.sublist(36 + 1 + scriptSize, 36 + 1 + scriptSize + 4);
      var script = bytes.sublist(36, 36 + 1 + scriptSize);
      return TransactionInput(txHash, index,
          ScriptSignature.forCoinbase(Codec.encodeHex(script)), sequence);
    }

    ScriptSignature script;
    //if (isSegwit || isUnsignedSignature) {
    if (bytes[36] == 0x00 && bytes[37] != 0x14) {
      script = ScriptSignature.empty();
    } else {
      var scriptSig = bytes.sublist(36);
      script = ScriptSignature.parse(Codec.encodeHex(scriptSig));
    }
    scriptSize = script.serialize().length ~/ 2;
    if (36 + scriptSize + 4 > bytes.length) {
      throw const FormatException('Truncated transaction input sequence.');
    }
    var sequence = bytes.sublist(36 + scriptSize, 36 + scriptSize + 4);
    return TransactionInput(txHash, index, script, sequence);
  }

  /// Parse the transaction input from the given input string for PSBT.
  factory TransactionInput.parseForPsbt(String input) {
    Uint8List bytes = Codec.decodeHex(input);
    if (bytes.length < 41) {
      throw const FormatException('Truncated unsigned transaction input.');
    }
    if (bytes[36] != 0x00) {
      throw const FormatException(
          'Unsigned transaction input must have an empty scriptSig.');
    }
    //print("full : " + Converter.bytesToHex(bytes));
    var txHash = bytes.sublist(0, 32);
    //print("txHash : " + Converter.bytesToHex(txHash));
    var index = bytes.sublist(32, 36);
    //print("index : " + Converter.bytesToHex(index));
    var sequence = bytes.sublist(37, 41);
    return TransactionInput(txHash, index, ScriptSignature.empty(), sequence);
  }

  /// Create a transaction input for sending.
  factory TransactionInput.forPayment(String transactionHash, int index,
      {int sequence = 0xffffffff}) {
    return TransactionInput(
        Uint8List.fromList(Codec.decodeHex(transactionHash).reversed.toList()),
        Converter.intToLittleEndianBytes(index, 4),
        ScriptSignature.empty(),
        Converter.intToLittleEndianBytes(sequence, 4));
  }

  /// Insert signature into the transaction input.
  void setSignature(AddressType addressType, List<Signature> signatureList,
      {MultisignatureScript? witnessScript}) {
    if (signatureList.isEmpty) {
      throw Exception("No signature found.");
    }

    if (!addressType.isMultisignature && signatureList.length > 1) {
      throw Exception(
          "Only one signature is allowed for single signature address.");
    }

    if (addressType == AddressType.p2pkh) {
      scriptSig = ScriptSignature.p2pkh(
          Codec.decodeHex(signatureList[0].signature),
          Codec.decodeHex(signatureList[0].publicKey));
    } else if (addressType == AddressType.p2wpkh) {
      scriptSig = ScriptSignature.p2wpkh();
      witnessList = [signatureList[0].signature, signatureList[0].publicKey];
    } else if (addressType == AddressType.p2wsh) {
      if (witnessScript == null) {
        throw ArgumentError('witnessScript is required for p2wsh');
      }
      signatureList.sort((a, b) => a.publicKey.compareTo(b.publicKey));

      scriptSig = ScriptSignature.p2wsh();
      witnessList = ["00"];
      for (int i = 0; i < signatureList.length; i++) {
        // int sigLength = signatureList[i].signature.length ~/ 2;
        // witnessList.add(Converter.decToHex(sigLength));
        witnessList.add(signatureList[i].signature);
      }
      witnessList.add(witnessScript.rawSerialize());
    } else {
      throw ArgumentError('Not supported address type');
    }
  }

  void setTaprootKeyPathSpendingSignature(String signature) {
    witnessList = [signature];
  }

  void setTaprootScriptPathSpendingSignature(
      String signature, String tapScript, String controlBlock) {
    witnessList = [signature, tapScript, controlBlock];
  }

  /// Check if the transaction input has signature.
  bool hasSignature(bool isSewit) {
    if (isSewit) {
      return witnessList.length >= 2;
    } else {
      return !(scriptSig.commands.length == 1 && scriptSig.commands[0] == 0x00);
    }
  }

  bool verifySpend(Uint8List sigHash, TransactionOutput utxo) {
    if (utxo.scriptPubKey.isP2wpkh()) {
      String signature;
      String publicKey;

      signature = witnessList[0];
      publicKey = witnessList[1];

      Uint8List sig = Codec.decodeHex(signature);
      Uint8List pub = Codec.decodeHex(publicKey);

      // commands[1] is stored as `dynamic` (Script commands are untyped),
      // so cast it to Uint8List first. Also compare byte content (Uint8List
      // uses identity for `==` / `!=`).
      final Uint8List scriptPubKeyHash =
          utxo.scriptPubKey.commands[1] as Uint8List;
      final Uint8List expectedPubKeyHash = Hash.sha160fromHex(publicKey);
      if (scriptPubKeyHash.length != expectedPubKeyHash.length) {
        return false;
      }
      for (int i = 0; i < scriptPubKeyHash.length; i++) {
        if (scriptPubKeyHash[i] != expectedPubKeyHash[i]) {
          return false;
        }
      }

      Uint8List rawSignature = Converter.derToRawSignature(sig);

      return Ecc.verifyEcdsa(sigHash, pub, rawSignature);
    } else if (utxo.scriptPubKey.isP2wsh()) {
      return _verifyP2wshSpend(sigHash, utxo);
    } else if (utxo.scriptPubKey.isP2tr()) {
      Uint8List outputKey =
          Uint8List.fromList((utxo.scriptPubKey.commands[1] as Uint8List));
      Uint8List signature = Codec.decodeHex(witnessList[0]);
      if (signature.length == 65) {
        if (signature.last == 0x00) return false;
        signature = signature.sublist(0, 64);
      } else if (signature.length != 64) {
        return false;
      }
      if (witnessList.length == 1) {
        // Key path spending
        return Ecc.verifySchnorr(sigHash, outputKey, signature);
      } else if (witnessList.length == 3) {
        // Script path spending
        final String tapscriptHex = witnessList[1];
        final Uint8List controlBlockBytes = Codec.decodeHex(witnessList[2]);

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
            Codec.encodeHex(outputKey)) {
          return false;
        }

        // Extract x-only pubkey from tapscript and verify signature.
        final Uint8List scriptWithLen = Uint8List.fromList([
          ...Codec.encodeVariableInteger(scriptBytes.length),
          ...scriptBytes
        ]);
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

        return Ecc.verifySchnorr(sigHash, pubkey, signature);
      } else {
        throw Exception('Invalid Taproot Transaction');
      }
    } else {
      throw Exception('Unsupported Address Type');
    }
  }

  bool _verifyP2wshSpend(Uint8List sigHash, TransactionOutput utxo) {
    try {
      if (witnessList.length < 3) {
        return false;
      }

      final String dummy = witnessList.first;
      if (dummy.isNotEmpty && dummy.toLowerCase() != '00') {
        return false;
      }

      final String script = witnessList.last;
      final Uint8List scriptBytes = Codec.decodeHex(script);
      final String size =
          Codec.encodeHex(Codec.encodeVariableInteger(scriptBytes.length));
      final MultisignatureScript witnessScript =
          MultisignatureScript.parse(size + script);

      final Uint8List scriptCommitment =
          utxo.scriptPubKey.commands[1] as Uint8List;
      final Uint8List actualScriptHash = Hash.sha256fromByte(scriptBytes);
      if (actualScriptHash.length != scriptCommitment.length) {
        return false;
      }
      for (int i = 0; i < actualScriptHash.length; i++) {
        if (actualScriptHash[i] != scriptCommitment[i]) {
          return false;
        }
      }

      final List<Uint8List> signatures = [
        for (int i = 1; i < witnessList.length - 1; i++)
          Codec.decodeHex(witnessList[i]),
      ];
      final List<Uint8List> publicKeys = witnessScript.getPublicKeys();
      final int requiredSignatures = witnessScript.getRequiredSignature();
      if (signatures.length != requiredSignatures) {
        return false;
      }

      int nextPublicKeyIndex = 0;
      for (int signatureIndex = 0;
          signatureIndex < signatures.length;
          signatureIndex++) {
        final Uint8List signature = signatures[signatureIndex];
        // This validation path currently computes SIGHASH_ALL only.
        if (signature.isEmpty || signature.last != 0x01) {
          return false;
        }
        final Uint8List rawSignature = Converter.derToRawSignature(signature);

        bool matched = false;
        while (nextPublicKeyIndex < publicKeys.length) {
          final int remainingPublicKeys =
              publicKeys.length - nextPublicKeyIndex;
          final int remainingSignatures = signatures.length - signatureIndex;
          if (remainingPublicKeys < remainingSignatures) {
            return false;
          }

          final Uint8List publicKey = publicKeys[nextPublicKeyIndex++];
          if (Ecc.verifyEcdsa(sigHash, publicKey, rawSignature)) {
            matched = true;
            break;
          }
        }
        if (!matched) {
          return false;
        }
      }
      return true;
    } on FormatException {
      return false;
    } on RangeError {
      return false;
    }
  }

  /// Serialize the transaction input.
  String serialize() {
    // print("Tx hash : " + Converter.bytesToHex(_transactionHash));
    // print("index : " + Converter.bytesToHex(_index));
    // print("script : " + _scriptSig.serialize());
    // print("seq : " + Converter.bytesToHex(_sequence));
    return Codec.encodeHex(_transactionHash) +
        Codec.encodeHex(_index) +
        scriptSig.serialize() +
        Codec.encodeHex(_sequence);
  }
}
