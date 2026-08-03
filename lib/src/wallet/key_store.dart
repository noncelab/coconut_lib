part of '../../coconut_lib.dart';

/// Key Store is consist of fingerprint, exPub and seed.
class KeyStore {
  String _masterFingerprint;
  HDWallet _hdWallet;
  HDWallet _hdWalletReceive;
  HDWallet _hdWalletChange;
  ExtendedPublicKey _extendedPublicKey;
  Seed? _seed;
  final Map<String, Uint8List> _muSig2SecretNonces = {};

  /// The fingerprint of the key store.
  String get masterFingerprint => _masterFingerprint;

  HDWallet get hdWallet => _hdWallet;

  /// @nodoc
  HDWallet getChildHdWallet(bool isChange) =>
      isChange ? _hdWalletChange : _hdWalletReceive;

  /// The extended public key of the key store.
  ExtendedPublicKey get extendedPublicKey => _extendedPublicKey;

  /// The seed of the key store.
  Seed get seed => _seed!;

  /// Set the seed of the key store.
  set seed(Seed? seed) {
    _seed = seed;
  }

  /// Check if the key store has seed.
  bool get hasSeed => _seed != null;

  /// @nodoc
  KeyStore(this._masterFingerprint, this._hdWallet, this._extendedPublicKey,
      [this._seed])
      : _hdWalletReceive = _hdWallet.derive(0),
        _hdWalletChange = _hdWallet.derive(1);

  /// Create a key store from a seed.
  factory KeyStore.fromSeed(Seed seed, AddressType addressType,
      {int accountIndex = 0}) {
    bool isTestnet = NetworkType.currentNetworkType.isTestnet;
    HDWallet rootWallet = HDWallet.fromRootSeed(seed.rootSeed);
    String fingerprint = Codec.encodeHex(rootWallet.fingerprint).toUpperCase();

    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);
    HDWallet wallet = rootWallet.derivePath(derivationPath);
    int version = isTestnet
        ? addressType.versionForTestnet
        : addressType.versionForMainnet;
    ExtendedPublicKey extendedPublicKey = ExtendedPublicKey.fromHdWallet(
        wallet, version, wallet.parentFingerprint);
    return KeyStore(fingerprint, wallet, extendedPublicKey, seed);
  }

  /// Create a key store from a mnemonic.
  factory KeyStore.fromMnemonic(Uint8List mnemonic, AddressType addressType,
      {Uint8List? passphrase, int accountIndex = 0}) {
    Seed seed = Seed.fromMnemonic(mnemonic, passphrase: passphrase);

    return KeyStore.fromSeed(seed, addressType, accountIndex: accountIndex);
  }

  /// Create a key store from a random.
  factory KeyStore.random(AddressType addressType,
      {int mnemonicLength = 24, Uint8List? passphrase, int accountIndex = 0}) {
    if (mnemonicLength != 12 &&
        mnemonicLength != 15 &&
        mnemonicLength != 18 &&
        mnemonicLength != 21 &&
        mnemonicLength != 24) {
      throw Exception('MnemonicLength must be 12, 15, 18, 21, or 24.');
    }

    Seed seed =
        Seed.random(mnemonicLength: mnemonicLength, passphrase: passphrase);
    return KeyStore.fromSeed(seed, addressType, accountIndex: accountIndex);
  }

  /// Create a key store from a entropy.
  factory KeyStore.fromEntropy(Uint8List entropy, AddressType addressType,
      {Uint8List? passphrase, int accountIndex = 0}) {
    Seed seed = Seed.fromEntropy(entropy, passphrase: passphrase);
    return KeyStore.fromSeed(seed, addressType, accountIndex: accountIndex);
  }

  factory KeyStore.fromExtendedPublicKey(
      String extendedPublicKey, String masterFingerprint) {
    ExtendedPublicKey exPub = ExtendedPublicKey.parse(extendedPublicKey);
    HDWallet wallet = HDWallet.fromPublicKey(exPub.publicKey, exPub.chainCode);
    return KeyStore(masterFingerprint, wallet, exPub);
  }

  factory KeyStore.fromSignerBsms(String signer) {
    Bsms bsms = Bsms.parseSigner(signer);
    // KeyStore(fingerprint, wallet, extendedPublicKey)
    HDWallet wallet = HDWallet.fromPublicKey(
        bsms.signer!.extendedPublicKey.publicKey,
        bsms.signer!.extendedPublicKey.chainCode);
    return KeyStore(
        bsms.signer!.masterFingerPrint, wallet, bsms.signer!.extendedPublicKey);
  }

  ///@nodoc
  factory KeyStore.fromJson(String json) {
    Map<String, dynamic> map = jsonDecode(json);
    String fingerprint = map['fingerprint'];
    HDWallet hdWallet = HDWallet.fromJson(map['hdWallet']);
    ExtendedPublicKey extendedPublicKey =
        ExtendedPublicKey.parse(map['extendedPublicKey']);
    Seed? seed = map['seed'] != null ? Seed.fromJson(map['seed']) : null;
    return KeyStore(fingerprint, hdWallet, extendedPublicKey, seed);
  }

  /// Get the private key of the key store using index.
  String getPrivateKey(int index,
      {bool isChange = false,
      bool applyTweak = false,
      bool isXOnly = false,
      Uint8List? merkleRoot,
      Uint8List? aggregatedPublicKey}) {
    if (!hasSeed) throw Exception('No private key in this key store');
    HDWallet child = getChildHdWallet(isChange).derive(index);
    Uint8List privKey = child.getPrivateKey(applyTweak, isXOnly,
        merkleRoot: merkleRoot, aggregatedPublicKey: aggregatedPublicKey);
    return Codec.encodeHex(privKey);
  }

  /// Get the public key of the key store using index.
  String getPublicKey(int addressIndex,
      {bool isChange = false,
      isXOnly = false,
      applyTweak = false,
      Uint8List? merkleRoot,
      Uint8List? aggregatedPublicKey}) {
    return Codec.encodeHex(getPublicKeyBytes(addressIndex,
        isChange: isChange,
        isXOnly: isXOnly,
        applyTweak: applyTweak,
        merkleRoot: merkleRoot,
        aggregatedPublicKey: aggregatedPublicKey));
  }

  Uint8List getPublicKeyBytes(int addressIndex,
      {bool isChange = false,
      isXOnly = false,
      applyTweak = false,
      Uint8List? merkleRoot,
      Uint8List? aggregatedPublicKey}) {
    HDWallet child = getChildHdWallet(isChange).derive(addressIndex).neutered();

    Uint8List publicKey = child.getPublicKey(applyTweak, isXOnly,
        merkleRoot: merkleRoot, aggregatedPublicKey: aggregatedPublicKey);

    return publicKey;
  }

  ///Check if the PSBT can be signed from this vault.
  bool hasPublicKeyInPsbt(String psbt) {
    Psbt psbtObj = Psbt.parse(psbt);
    if (psbtObj.inputs.isEmpty) {
      throw Exception("PSBT has no inputs.");
    }

    if (psbtObj.inputs[0].bip32Derivation != null) {
      for (int i = 0; i < psbtObj.unsignedTransaction!.inputs.length; i++) {
        PsbtInput thisInput = psbtObj.inputs[i];
        for (int j = 0; j < thisInput.derivationPathList.length; j++) {
          String publicKeyInPsbt = thisInput.derivationPathList[j].publicKey;
          String publicKey = getPublicKey(
              thisInput.derivationPathList[j].accountIndex,
              isChange: thisInput.derivationPathList[j].isChange);
          if (publicKeyInPsbt.length != publicKey.length) {
            publicKey = publicKey.substring(2);
          }
          if (thisInput.derivationPathList[j].masterFingerprint ==
              masterFingerprint) {
            if (publicKeyInPsbt == publicKey) {
              return true;
            }
          }
        }
      }
      return false;
    } else if (psbtObj.inputs[0].tapBip32Derivation != null) {
      // taproot
      for (int i = 0; i < psbtObj.unsignedTransaction!.inputs.length; i++) {
        PsbtInput thisInput = psbtObj.inputs[i];
        for (int j = 0; j < thisInput.tapBip32Derivation!.length; j++) {
          String publicKeyInPsbt = thisInput.tapBip32Derivation![j].publicKey;
          String publicKey = getPublicKey(
              thisInput.tapBip32Derivation![j].accountIndex,
              isChange: thisInput.tapBip32Derivation![j].isChange,
              isXOnly: false);
          if (publicKeyInPsbt.length != publicKey.length) {
            publicKey = publicKey.substring(2);
          }

          if (thisInput.tapBip32Derivation![j].masterFingerprint ==
              masterFingerprint) {
            if (publicKeyInPsbt == publicKey) {
              return true;
            }
          }
        }
      }
      return false;
    } else {
      throw Exception("Derivation path is not included in psbt.");
    }
  }

  String addPublicNonceToPsbt(String psbt) {
    if (!hasSeed) {
      throw Exception('This key store does not have seed');
    }
    Psbt psbtObject = Psbt.parse(psbt);
    if (psbtObject.addressType != AddressType.p2tr) {
      throw Exception('Only p2tr needs public nonce.');
    }
    if (psbtObject.inputs.length !=
        psbtObject.unsignedTransaction!.inputs.length) {
      throw Exception('Not enought psbt inputs or transaction inputs');
    }
    List<TransactionOutput> utxoList = [];
    if (hasPublicKeyInPsbt(psbtObject.serialize()) == false) {
      throw Exception('This vault can not sign this PSBT');
    }
    for (int j = 0; j < psbtObject.unsignedTransaction!.inputs.length; j++) {
      utxoList.add(psbtObject.inputs[j].witnessUtxo!);
    }
    for (int inputIndex = 0;
        inputIndex < psbtObject.unsignedTransaction!.inputs.length;
        inputIndex++) {
      PsbtInput psbtInput = psbtObject.inputs[inputIndex];
      String sigHash = psbtObject.unsignedTransaction!
          .getTaprootSigHash(inputIndex, utxoList);
      for (DerivationPath derivationPath in psbtInput.tapBip32Derivation!) {
        if (masterFingerprint == derivationPath.masterFingerprint) {
          addPublicNonceToPsbtInput(psbtInput, derivationPath.path, sigHash);
        }
      }
    }
    return psbtObject.serialize();
  }

  void addPublicNonceToPsbtInput(
      PsbtInput psbtInput, String derivationPath, String sigHash,
      {String extraInput = ''}) {
    if (!hasSeed) {
      throw Exception('This vault does not have seed');
    }

    int accountIndex =
        WalletUtility.getAccountIndexFromDerivationPath(derivationPath);
    bool isChange = WalletUtility.isChangeFromDerivationPath(derivationPath);
    String publicKey =
        getPublicKey(accountIndex, isChange: isChange, isXOnly: false);
    String publicNonce = getPublicNonce(
        sigHash, psbtInput.muSig2AggregatedPublicKey!, accountIndex, isChange,
        extraInput: Codec.decodeHex(extraInput));
    psbtInput.addMuSig2PubNonce(
        publicKey, psbtInput.muSig2AggregatedPublicKey!, sigHash, publicNonce);
  }

  String addSignatureToPsbt(String psbt, AddressType addressType) {
    if (!hasSeed) {
      throw Exception('This vault does not have seed');
    }
    Psbt psbtObject = Psbt.parse(psbt);
    if (hasPublicKeyInPsbt(psbtObject.serialize()) == false) {
      throw Exception('This vault can not sign this PSBT');
    }
    if (psbtObject.inputs.length !=
        psbtObject.unsignedTransaction!.inputs.length) {
      throw Exception('Not enought psbt inputs or transaction inputs');
    }

    for (int inputIndex = 0;
        inputIndex < psbtObject.unsignedTransaction!.inputs.length;
        inputIndex++) {
      PsbtInput psbtInput = psbtObject.inputs[inputIndex];

      if (psbtInput.requiredSignature <= psbtInput.signedCount) {
        continue;
      }

      // Generate sig hash
      late String sigHash;

      if (!addressType.isTaproot) {
        // ECDSA
        TransactionOutput utxo = psbtInput.witnessUtxo!;
        if (addressType == AddressType.p2wsh) {
          String? witnessScript = psbtInput.witnessScript!.rawSerialize();
          sigHash = psbtObject.unsignedTransaction!.getSigHash(
              inputIndex, utxo, addressType,
              witnessScript: witnessScript);
        } else {
          sigHash = psbtObject.unsignedTransaction!
              .getSigHash(inputIndex, utxo, addressType);
        }
      } else {
        // Taproot
        List<TransactionOutput> utxoList = [];
        for (int j = 0;
            j < psbtObject.unsignedTransaction!.inputs.length;
            j++) {
          utxoList.add(psbtObject.inputs[j].witnessUtxo!);
        }
        sigHash = psbtObject.unsignedTransaction!
            .getTaprootSigHash(inputIndex, utxoList);
      }
      //get derivation path
      late String derivationPath;
      for (int i = 0; i < psbtInput.derivationPathList.length; i++) {
        String path = psbtInput.derivationPathList[i].path;
        if (psbtInput.derivationPathList[i].publicKey ==
            getPublicKey(WalletUtility.getAccountIndexFromDerivationPath(path),
                isChange: WalletUtility.isChangeFromDerivationPath(path),
                isXOnly: addressType.isTaproot)) {
          derivationPath = psbtInput.derivationPathList[i].path;
          break;
        }
        if (i == psbtInput.derivationPathList.length - 1) {
          throw Exception('Derivation path not found');
        }
      }

      // String derivationPath = psbtInput.derivationPathList[inputIndex].path;
      SessionContext? sessionContext;
      if (addressType == AddressType.p2tr) {
        sessionContext = SessionContext(
            psbtInput.muSig2ParticipantPubkeys!
                .map((e) => Codec.decodeHex(e))
                .toList(),
            Codec.decodeHex(psbtInput.getAggregatedPublicNonce()),
            Codec.decodeHex(psbtInput.muSig2AggregatedPublicKey!),
            Codec.decodeHex(sigHash),
            merkleRoot: (psbtInput.tapMerkleRoot != null &&
                    psbtInput.tapMerkleRoot!.isNotEmpty)
                ? Codec.decodeHex(psbtInput.tapMerkleRoot!)
                : null,
            applyTaprootTweak: true);
      }

      addSignatureToPsbtInput(psbtInput, addressType, derivationPath, sigHash,
          aggregatedPublicKey: psbtInput.muSig2AggregatedPublicKey,
          sessionContext: sessionContext);
    }
    return psbtObject.serialize();
  }

  ///add signature to PSBT if it's possible.
  void addSignatureToPsbtInput(PsbtInput psbtInput, AddressType addressType,
      String derivationPath, String sigHash,
      {String? aggregatedPublicKey, SessionContext? sessionContext}) {
    if (!hasSeed) {
      throw Exception('This vault does not have seed.');
    }
    int accountIndex =
        WalletUtility.getAccountIndexFromDerivationPath(derivationPath);
    bool isChange = WalletUtility.isChangeFromDerivationPath(derivationPath);
    HDWallet hdWallet = getChildHdWallet(isChange).derive(accountIndex);

    String publicKey;
    late String signature;

    if (!addressType.isTaproot) {
      // ECDSA
      publicKey =
          getPublicKey(accountIndex, isChange: isChange, isXOnly: false);
      signature = Codec.encodeHex(hdWallet.signEcdsa(Codec.decodeHex(sigHash)));
    } else {
      if (psbtInput.tapLeafScript != null) {
        //Script path spending
        publicKey = getPublicKey(accountIndex,
            isChange: isChange, applyTweak: false, isXOnly: true);
        signature = Codec.encodeHex(
            hdWallet.signSchnorr(Codec.decodeHex(sigHash), false));
      }
      //Key path spending
      else if (psbtInput.tapLeafScript == null && sessionContext == null) {
        final Uint8List? merkleRoot = (psbtInput.tapMerkleRoot != null &&
                psbtInput.tapMerkleRoot!.isNotEmpty)
            ? Codec.decodeHex(psbtInput.tapMerkleRoot!)
            : null;
        publicKey = getPublicKey(accountIndex,
            isChange: isChange,
            applyTweak: true,
            isXOnly: false,
            merkleRoot: merkleRoot);
        signature = Codec.encodeHex(hdWallet.signSchnorr(
            Codec.decodeHex(sigHash), true,
            merkleRoot: merkleRoot));
      } else if (psbtInput.tapLeafScript == null && sessionContext != null) {
        //MuSig2
        publicKey =
            getPublicKey(accountIndex, isChange: isChange, isXOnly: false);
        if (psbtInput.tapBip32Derivation!.length !=
            psbtInput.muSig2PubNonces!.length) {
          throw Exception("Not enough public nonce.");
        }
        final String nonceKey = _createMuSig2NonceKey(
            publicKey, psbtInput.muSig2AggregatedPublicKey!, sigHash);
        final String? expectedPublicNonce =
            psbtInput.muSig2PubNonces?[nonceKey];
        if (expectedPublicNonce == null) {
          throw StateError('No MuSig2 public nonce for this signer.');
        }
        Uint8List secretNonce =
            _takeMuSig2SecretNonce(nonceKey, expectedPublicNonce);

        try {
          signature = Codec.encodeHex(
              hdWallet.signSchnorrForMuSig2(secretNonce, sessionContext));
        } finally {
          secretNonce.fillRange(0, secretNonce.length, 0);
        }
      } else {
        throw Exception('Invalid PSBT input.');
      }
    }

    // 3. Validate signature

    Uint8List signatureByte = Codec.decodeHex(signature);
    Uint8List publicKeyByte = Codec.decodeHex(publicKey);

    if (!addressType.isTaproot) {
      // ECDSA
      if (!Ecc.verifyEcdsa(Codec.decodeHex(sigHash), publicKeyByte,
          Converter.derToRawSignature(signatureByte))) {
        throw Exception('Invalid signature');
      }
    } else {
      // Schnorr
      if (psbtInput.tapLeafScript != null) {
        if (!Ecc.verifySchnorr(
            Codec.decodeHex(sigHash), publicKeyByte, signatureByte)) {
          throw Exception('Invalid signature');
        }
      } else if (psbtInput.tapLeafScript == null && sessionContext == null) {
        if (!Ecc.verifySchnorr(
            Codec.decodeHex(sigHash), publicKeyByte, signatureByte)) {
          throw Exception('Invalid signature');
        }
      } else if (psbtInput.tapLeafScript == null && sessionContext != null) {
        Uint8List publicNonce = Codec.decodeHex(psbtInput.muSig2PubNonces![
            "${Codec.encodeHex(publicKeyByte)}$aggregatedPublicKey$sigHash"]!);
        if (!Ecc.verifyMuSig2PartialSignature(
            signatureByte, publicNonce, publicKeyByte, sessionContext)) {
          throw Exception('Invalid signature');
        }
      } else {
        throw Exception('Invalid PSBT input.');
      }
    }

    // 4. Attach signature to PSBT
    if (!addressType.isTaproot) {
      // ECDSA
      // psbtObject.addPartialSig(inputIndex, signatureMap[pub]!, pub);
      psbtInput.addPartialSig(signature, publicKey);
    } else {
      // Taproot
      if (psbtInput.tapLeafScript != null) {
        psbtInput.addTapScriptSig(signature, publicKey);
      }
      if (psbtInput.muSig2AggregatedPublicKey == null) {
        // Key path spending
        psbtInput.addTapKeySig(signature);
      } else {
        // MuSig2
        psbtInput.addMuSig2PartialSig(signature, publicKey,
            psbtInput.muSig2AggregatedPublicKey!, sigHash);
      }
    }
  }

  Uint8List getSecretNonce(String sigHash, String aggregatedPublicKey,
      int accountIndex, bool isChange,
      {Uint8List? extraInput}) {
    Uint8List secretKey = Codec.decodeHex(
        getPrivateKey(accountIndex, isChange: isChange, isXOnly: false));
    Uint8List publicKey = Codec.decodeHex(
        getPublicKey(accountIndex, isChange: isChange, isXOnly: false));
    Uint8List aggPubkey = Codec.decodeHex(aggregatedPublicKey);
    Uint8List message = Codec.decodeHex(sigHash);
    final Random secureRandom = Random.secure();
    final Uint8List rand = Uint8List.fromList(
        List<int>.generate(32, (_) => secureRandom.nextInt(256)));
    Uint8List secretNonce = calculateSecretNonce(
        rand, secretKey, publicKey, aggPubkey, message, extraInput,
        isDeterministic: false);
    return secretNonce;
  }

  static Uint8List calculateSecretNonce(
      Uint8List rand,
      Uint8List secretKey,
      Uint8List publicKey,
      Uint8List aggPubkey,
      Uint8List message,
      Uint8List? extraInput,
      {bool isDeterministic = true}) {
    if (!isDeterministic) {
      final auxHash = Hash.taggedHash("MuSig/aux", rand);
      final result = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        result[i] = secretKey[i] ^ auxHash[i];
      }
      rand = result;
    }

    Uint8List mPrefixed;
    final len = message.length;
    final lenBytes = Uint8List(8)..buffer.asByteData().setUint64(0, len);
    mPrefixed = Uint8List.fromList([0x01, ...lenBytes, ...message]);
    extraInput ??= Uint8List(0);
    final extraLenBytes = Uint8List(4)
      ..buffer.asByteData().setUint32(0, extraInput.length);

    // Step 4: compute k1, k2
    Uint8List? k1, k2;
    List<Uint8List> scalars = [];
    for (int i = 1; i <= 2; i++) {
      final prefix = Uint8List.fromList([i - 1]);
      final input = Uint8List.fromList([
        ...rand,
        // 1,
        publicKey.length,
        ...publicKey,
        // 1,
        aggPubkey.length,
        ...aggPubkey,
        ...mPrefixed,
        ...extraLenBytes,
        ...extraInput,
        ...prefix
      ]);
      final hash = Hash.taggedHash("MuSig/nonce", input);
      scalars.add(hash);
    }
    k1 = scalars[0];
    k2 = scalars[1];
    Uint8List secretNonce = Uint8List.fromList([...k1, ...k2, ...publicKey]);
    return secretNonce;
  }

  String getPublicNonce(String sigHash, String aggregatedPublicKey,
      int accountIndex, bool isChange,
      {Uint8List? extraInput}) {
    Uint8List secretNonce = getSecretNonce(
        sigHash, aggregatedPublicKey, accountIndex, isChange,
        extraInput: extraInput);
    Uint8List publicNonce = calculatePublicNonce(secretNonce);
    final String publicKey =
        getPublicKey(accountIndex, isChange: isChange, isXOnly: false);
    final String nonceKey =
        _createMuSig2NonceKey(publicKey, aggregatedPublicKey, sigHash);
    final Uint8List? replacedNonce = _muSig2SecretNonces.remove(nonceKey);
    replacedNonce?.fillRange(0, replacedNonce.length, 0);
    _muSig2SecretNonces[nonceKey] = Uint8List.fromList(secretNonce);
    return Codec.encodeHex(publicNonce);
  }

  String _createMuSig2NonceKey(
          String publicKey, String aggregatedPublicKey, String sigHash) =>
      '$publicKey$aggregatedPublicKey$sigHash';

  Uint8List _takeMuSig2SecretNonce(
      String nonceKey, String expectedPublicNonce) {
    final Uint8List? secretNonce = _muSig2SecretNonces.remove(nonceKey);
    if (secretNonce == null) {
      throw StateError(
          'MuSig2 secret nonce is unavailable or has already been consumed.');
    }

    final String actualPublicNonce =
        Codec.encodeHex(calculatePublicNonce(secretNonce));
    if (actualPublicNonce != expectedPublicNonce.toLowerCase()) {
      secretNonce.fillRange(0, secretNonce.length, 0);
      throw StateError(
          'MuSig2 public nonce does not match stored secret nonce.');
    }

    return secretNonce;
  }

  static Uint8List calculatePublicNonce(Uint8List secretNonce) {
    final k1 = secretNonce.sublist(0, 32);
    final k2 = secretNonce.sublist(32, 64);
    final r1 = Ecc.pointFromScalar(k1, true);
    final r2 = Ecc.pointFromScalar(k2, true);
    return Uint8List.fromList([...r1!, ...r2!]);
  }

  ///@nodoc
  String toJson() {
    return jsonEncode({
      'fingerprint': _masterFingerprint,
      'hdWallet': _hdWallet.toJson(),
      'extendedPublicKey': _extendedPublicKey.serialize(),
      if (_seed != null) 'seed': _seed!.toJson()
    });
  }

  //wipe the seed
  void wipeSeed() {
    for (final Uint8List secretNonce in _muSig2SecretNonces.values) {
      secretNonce.fillRange(0, secretNonce.length, 0);
    }
    _muSig2SecretNonces.clear();

    final HDWallet publicHdWallet = _hdWallet.neutered();
    _hdWalletReceive.wipePrivateKey();
    _hdWalletChange.wipePrivateKey();
    _hdWallet.wipePrivateKey();
    _hdWallet = publicHdWallet;
    _hdWalletReceive = _hdWallet.derive(0);
    _hdWalletChange = _hdWallet.derive(1);

    if (_seed != null) {
      _seed!.wipe();
      _seed = null;
    }
  }

  ///@nodoc
  @override
  String toString() {
    return 'KeyStore{fingerprint: $_masterFingerprint, extendedPublicKey: $_extendedPublicKey}';
  }

  ///@nodoc
  @override
  bool operator ==(Object other) {
    if (other is KeyStore) {
      return _masterFingerprint == other._masterFingerprint &&
          _extendedPublicKey == other._extendedPublicKey &&
          _seed == other._seed;
    }
    return false;
  }

  ///@nodoc
  @override
  int get hashCode =>
      _masterFingerprint.hashCode ^
      _extendedPublicKey.hashCode ^
      _seed.hashCode;
}

/// BIP327 `ApplyTweak` on [KeyAgg Context] (see [KeyAgg Context] in BIP-0327).
(ECPoint qP, BigInt gaccP, BigInt taccP) _musigApplyTweakKeyAgg(
  ECPoint Q,
  BigInt gacc,
  BigInt tacc,
  Uint8List tweak,
  bool isXonlyT,
) {
  final oddY = Q.y!.toBigInteger()!.isOdd;
  final BigInt gPoint = (isXonlyT && oddY) ? (Ecc.n - BigInt.one) : BigInt.one;

  final t = Ecc.fromBuffer(tweak);
  ECPoint qWork = Q;
  if (gPoint == Ecc.n - BigInt.one) {
    qWork = Ecc.decodeFrom(Ecc.pointNegate(Ecc.getEncoded(Q, true))!)!;
  }
  final tG = (Ecc.G * t)!;
  final qP = (qWork + tG)!;
  if (qP.isInfinity) {
    throw Exception('MuSig2 ApplyTweak: invalid aggregate point');
  }
  final gaccP = (gPoint * gacc) % Ecc.n;
  final taccP = (t + gPoint * tacc) % Ecc.n;
  return (qP, gaccP, taccP);
}

class SessionContext {
  final List<Uint8List> participantPublicKeys;
  final Uint8List aggregatedPubNonce;
  final Uint8List aggregatedPublicKey;
  Uint8List? merkleRoot;
  final Uint8List message;

  /// If true, apply BIP341 TapTweak to the internal aggregate key (Taproot key path).
  /// BIP327 unit tests use `false` (no tweaks, v == 0).
  final bool applyTaprootTweak;

  /// Final aggregate public key [Q] after optional tweaks (BIP327 GetSessionValues).
  late ECPoint aggregateQ;

  /// Accumulated [gacc] after [ApplyTweak] (BIP327).
  late BigInt musigGacc;

  /// Accumulated [tacc] after [ApplyTweak] (BIP327).
  late BigInt musigTacc;

  late BigInt b;
  late ECPoint R;
  late BigInt e;

  SessionContext(
    this.participantPublicKeys,
    this.aggregatedPubNonce,
    this.aggregatedPublicKey,
    this.message, {
    this.merkleRoot,
    this.applyTaprootTweak = true,
  }) {
    if (message.length != 32) {
      throw ArgumentError("sighash must be 32 bytes (got ${message.length})");
    }
    if (aggregatedPubNonce.length != 66) {
      throw ArgumentError(
          "aggregatedPubNonce must be 66 bytes (got ${aggregatedPubNonce.length})");
    }
    if (aggregatedPublicKey.length != 33) {
      throw ArgumentError(
          "aggregatedPublicKey must be 33 bytes (got ${aggregatedPublicKey.length})");
    }
    if (merkleRoot != null && merkleRoot!.length != 32) {
      throw ArgumentError(
          "merkleRoot must be 32 bytes (got ${merkleRoot!.length})");
    }
    merkleRoot ??= Uint8List(0);

    for (var key in participantPublicKeys) {
      if (key.length != 33) {
        throw Exception(
            "participantPublicKeys must be 33 bytes (got ${key.length})");
      }
    }

    // BIP327 requires KeySort (lexicographic) before KeyAgg (thus before L,
    // secondKey selection, and KeyAgg coefficients are computed).
    participantPublicKeys.sort((a, b) {
      int len = a.length < b.length ? a.length : b.length;
      for (int i = 0; i < len; i++) {
        if (a[i] != b[i]) return a[i].compareTo(b[i]);
      }
      return a.length.compareTo(b.length);
    });

    final ECPoint q0 = Ecc.decodeFrom(aggregatedPublicKey)!;

    if (applyTaprootTweak) {
      final Uint8List internalXOnly = aggregatedPublicKey.sublist(1);
      final Uint8List tapTweakBytes =
          Hash.hashTapTweak('TapTweak', internalXOnly, merkleRoot);
      final tweaked = _musigApplyTweakKeyAgg(
        q0,
        BigInt.one,
        BigInt.zero,
        tapTweakBytes,
        true,
      );
      aggregateQ = tweaked.$1;
      musigGacc = tweaked.$2;
      musigTacc = tweaked.$3;
    } else {
      aggregateQ = q0;
      musigGacc = BigInt.one;
      musigTacc = BigInt.zero;
    }

    b = Ecc.fromBuffer(Hash.taggedHash(
        "MuSig/noncecoef",
        Uint8List.fromList([
          ...aggregatedPubNonce,
          ...Ecc.getEncoded(aggregateQ, true).sublist(1),
          ...message
        ])));

    final r1 = Ecc.decodeFrom(aggregatedPubNonce.sublist(0, 33))!;
    final r2 = Ecc.decodeFrom(aggregatedPubNonce.sublist(33, 66))!;

    R = (r1 + r2 * b)!;

    Uint8List rX = Ecc.getEncoded(R, false).sublist(1, 33);

    e = Ecc.fromBuffer(Hash.taggedHash(
        "BIP0340/challenge",
        Uint8List.fromList([
          ...rX,
          ...Ecc.getEncoded(aggregateQ, true).sublist(1),
          ...message
        ])));
  }
}
