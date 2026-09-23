part of '../../coconut_lib.dart';

abstract class TaprootWalletBase extends WalletBase {
  final List<KeyStore> _keyStoreList;
  final List<Policy> _policyList;
  final bool _isVault;
  TapTree? _tapTree;

  /// Get the list of keyStores.
  List<KeyStore> get keyStoreList => List.unmodifiable(_keyStoreList);

  /// Check if this is a vault.
  bool get isVault => _isVault;

  /// Get the list of miniscripts.
  List<Policy> get policyList => List.unmodifiable(_policyList);

  /// Script tree committed to by this wallet, or null when there is none.
  ///
  /// The shape decides the merkle root and so the address. It comes from
  /// [tapTree] when the caller supplied one — a descriptor, say — and
  /// otherwise from [TapTree.fromPolicies].
  TapTree? get tapTree => _tapTree;

  /// @nodoc
  ///
  /// [tapTree] fixes how the policies are grouped. Supply it whenever the
  /// shape was specified elsewhere: its leaves are taken in their given order
  /// and are never re-sorted, because the position of a leaf is part of what
  /// the tree means.
  TaprootWalletBase(List<KeyStore> keyStoreList, List<Policy> policyList,
      String derivationPath, this._isVault,
      {TapTree? tapTree})
      : _keyStoreList = List<KeyStore>.of(keyStoreList),
        _policyList =
            tapTree != null ? tapTree.leaves : List<Policy>.of(policyList),
        _tapTree = tapTree,
        super(AddressType.p2tr, derivationPath) {
    if (!_addressType.isTaproot) {
      throw StateError('Taproot wallet must use a Taproot address type.');
    }

    _keyStoreList
        .sort((a, b) => a.masterFingerprint.compareTo(b.masterFingerprint));

    for (KeyStore keyStore in _keyStoreList) {
      if (NetworkType.currentNetworkType.isTestnet !=
          AddressType.isTestnetVersion(keyStore.extendedPublicKey.version)) {
        throw WalletException(
            WalletErrorCode.networkMismatch, 'Network type mismatch.');
      }
    }

    // Check derivation path
    final segments = derivationPath.split('/');
    if (segments.length < 3 || segments[0] != 'm') {
      throw WalletException(WalletErrorCode.derivationPathMismatch,
          'Invalid wallet derivation path.');
    }
    final coinTypeSegment = segments[2];

    final coinType =
        int.tryParse(coinTypeSegment.replaceAll(RegExp(r"[h']"), ""));

    if (coinType == 1 && !NetworkType.currentNetworkType.isTestnet) {
      throw WalletException(WalletErrorCode.derivationPathMismatch,
          'Derivation path coin type does not match the network.');
    } else if (coinType == 0 && NetworkType.currentNetworkType.isTestnet) {
      throw WalletException(WalletErrorCode.derivationPathMismatch,
          'Derivation path coin type does not match the network.');
    }

    // Deterministic policy order: TapLeaf hash at receive index 0 (lexicographic).
    // Tie-break with miniscript when hashes match. Only for a bare policy list:
    // an explicit tree already fixes both order and grouping.
    if (_tapTree == null && _policyList.length > 1) {
      _policyList.sort((a, b) {
        final cmp = _lexicographicCompare(
          a.getTapleafHash(0, isChange: false),
          b.getTapleafHash(0, isChange: false),
        );
        if (cmp != 0) return cmp;
        return a.toMiniscript().compareTo(b.toMiniscript());
      });
    }
    _tapTree ??= TapTree.fromPolicies(_policyList);

    _descriptor = Descriptor.forTaproot(_addressType, _keyStoreList, _tapTree,
        _derivationPath.replaceAll("m/", ""));
  }

  /// Get the internal key of the given index.
  Uint8List getInternalKey(int addressIndex, {bool isChange = false}) {
    // Key path spending
    if (keyStoreList.length == 1) {
      return keyStoreList[0].getPublicKeyBytes(addressIndex,
          isChange: isChange, isXOnly: true, applyTweak: false);
    }
    // MuSig2
    else if (keyStoreList.length > 1) {
      return getAggregatedPublicKey(addressIndex,
          isChange: isChange, isXOnly: true);
    } else {
      throw WalletException(
          WalletErrorCode.missingMetadata, 'No key store found.');
    }
  }

  /// Get the address of the given index.
  @override
  String getAddress(int addressIndex, {bool isChange = false}) {
    return _addressType.getTaprootAddress(
        Codec.encodeHex(getOutputKey(addressIndex, isChange: isChange)));
  }

  Uint8List getOutputKey(int addressIndex, {bool isChange = false}) {
    Uint8List internalKey = getInternalKey(addressIndex, isChange: isChange);
    Uint8List merkleRoot = Uint8List(0);

    if (_policyList.isNotEmpty) {
      merkleRoot = getMerkleRoot(addressIndex, isChange: isChange);
    }

    Uint8List keyToTweak = internalKey;
    Uint8List hashTapTweak =
        Hash.hashTapTweak('TapTweak', keyToTweak, merkleRoot);

    Uint8List tweakedPubKey =
        Ecc.pointAddScalar(keyToTweak, hashTapTweak, true)!;

    if (tweakedPubKey[0] == 0x03) {
      tweakedPubKey = Ecc.pointNegate(tweakedPubKey)!;
    }

    Uint8List outputKey = tweakedPubKey.sublist(1);
    return outputKey;
  }

  @override
  String getAddressWithDerivationPath(String derivationPath) {
    if (!WalletUtility.validateDerivationPath(derivationPath)) {
      throw WalletException(WalletErrorCode.derivationPathMismatch,
          "Invalid derivation path (e.g., m/44'/0'/0'/0/0).");
    }

    if (!derivationPath.startsWith('$_derivationPath/')) {
      throw WalletException(WalletErrorCode.derivationPathMismatch,
          'Derivation path does not belong to this wallet.',
          context: {'path': derivationPath, 'walletPath': _derivationPath});
    }
    int addressIndex =
        WalletUtility.getAccountIndexFromDerivationPath(derivationPath);
    bool isChange = WalletUtility.isChangeFromDerivationPath(derivationPath);
    return getAddress(addressIndex, isChange: isChange);
  }

  @override
  String getKeyOriginExpression() {
    List<String> keyOriginExpressionList = [];
    for (KeyStore keyStore in keyStoreList) {
      keyOriginExpressionList
          .add(Descriptor.getKeyOriginExpression(keyStore, derivationPath));
    }
    return keyOriginExpressionList.join(',');
  }

  @override
  bool hasPublicKeyInPsbt(String psbt) {
    Psbt psbtObject = Psbt.parse(psbt);
    if (psbtObject.addressType != addressType) {
      throw PsbtException(
          PsbtErrorCode.policyMismatch, 'PSBT address type does not match.');
    }
    if (addressType != AddressType.p2tr) {
      throw StateError('Taproot wallet must use a Taproot address type.');
    }
    if (psbtObject.inputs.length !=
        psbtObject.unsignedTransaction!.inputs.length) {
      throw PsbtException(PsbtErrorCode.transactionInputMismatch,
          'PSBT input count does not match the unsigned transaction.');
    }
    Set<KeyStore> targetkeyStoreSet = {};
    for (PsbtInput psbtInput in psbtObject.inputs) {
      if (psbtInput.tapLeafScript != null) {
        for (Policy policy in _policyList) {
          targetkeyStoreSet.addAll(policy.keyStoreList);
        }
      } else {
        for (KeyStore keyStore in _keyStoreList) {
          targetkeyStoreSet.add(keyStore);
        }
      }
    }
    return targetkeyStoreSet.isNotEmpty &&
        targetkeyStoreSet.any(
            (keyStore) => keyStore.hasPublicKeyInPsbt(psbtObject.serialize()));
  }

  @override
  String addSignatureToPsbt(String psbt) {
    Psbt psbtObject = Psbt.parse(psbt);
    if (psbtObject.addressType != addressType) {
      throw PsbtException(
          PsbtErrorCode.policyMismatch, 'PSBT address type does not match.');
    }

    if (addressType != AddressType.p2tr) {
      throw StateError('Taproot wallet must use a Taproot address type.');
    }

    if (!hasPublicKeyInPsbt(psbt)) {
      throw SigningException(
          SigningErrorCode.signerMismatch, 'No key store can sign this PSBT.');
    }

    if (psbtObject.inputs.length !=
        psbtObject.unsignedTransaction!.inputs.length) {
      throw PsbtException(PsbtErrorCode.transactionInputMismatch,
          'PSBT input count does not match the unsigned transaction.');
    }

    if (this is! TaprootVault) {
      throw StateError('Taproot policy validation requires a vault.');
    }
    psbtObject.validateTaprootPolicy(this as TaprootVault);

    for (int inputIndex = 0;
        inputIndex < psbtObject.inputs.length;
        inputIndex++) {
      //in every input
      PsbtInput psbtInput = psbtObject.inputs[inputIndex];
      if (psbtInput.requiredSignature <= psbtInput.signedCount) {
        continue;
      }

      List<TransactionOutput> utxoList = [];
      for (int j = 0; j < psbtObject.unsignedTransaction!.inputs.length; j++) {
        utxoList.add(psbtObject.inputs[j].witnessUtxo!);
      }

      // Default (key-path) taproot sighash; may be overridden for tapscript spends.
      String sigHash = psbtObject.unsignedTransaction!.getTaprootSigHash(
          inputIndex, utxoList,
          hashType: psbtInput.taprootSighashType);
      List<DerivationPath>? derivationPathList = psbtInput.tapBip32Derivation;
      //Script path spending
      if (psbtInput.tapLeafScript != null) {
        final Uint8List raw =
            Codec.decodeHex(psbtInput.tapLeafScript!.rawSerialize());
        final Uint8List size = Codec.encodeVariableInteger(raw.length);
        final Uint8List tapleafHash = Hash.taggedHash(
            'TapLeaf', Uint8List.fromList([0xc0, ...size, ...raw]));
        sigHash = psbtObject.unsignedTransaction!.getTaprootSigHash(
            inputIndex, utxoList,
            hashType: psbtInput.taprootSighashType,
            // tapscript keyVersion is 0 (BIP342); leaf version is committed in tapleafHash
            isTapscript: true,
            tapleafHash: tapleafHash,
            keyVersion: 0,
            codesepPos: 0xffffffff);
        final bool inputNeedsSignature =
            psbtInput.requiredSignature > psbtInput.signedCount;
        bool signed = false;
        for (DerivationPath derivationPath in derivationPathList!) {
          if (psbtInput.requiredSignature <= psbtInput.signedCount) {
            break;
          }
          for (Policy policy in _policyList) {
            KeyStore? signer;
            for (KeyStore keyStore in policy.keyStoreList) {
              // Only this vault's own seed can sign; cosigners sign their copy.
              if (keyStore.hasSeed &&
                  keyStore.masterFingerprint ==
                      derivationPath.masterFingerprint) {
                signer = keyStore;
                break;
              }
            }
            if (signer != null) {
              signer.addSignatureToPsbtInput(
                  psbtInput, addressType, derivationPath.path, sigHash);
              signed = true;
              break;
            }
          }
        }
        if (inputNeedsSignature && !signed) {
          throw SigningException(SigningErrorCode.privateKeyUnavailable,
              'This vault holds no seed for the Taproot script policy.',
              context: {'inputIndex': inputIndex});
        }
      }
      //Key path spending
      else if (psbtInput.tapLeafScript == null && keyStoreList.length == 1) {
        for (DerivationPath derivationPath in derivationPathList!) {
          //key path spending
          if (derivationPath.masterFingerprint ==
              keyStoreList[0].masterFingerprint) {
            keyStoreList[0].addSignatureToPsbtInput(
                psbtInput, addressType, derivationPath.path, sigHash);
            break;
          }
        }
      }
      //MuSig2
      else if (psbtInput.tapLeafScript == null && keyStoreList.length > 1) {
        if (psbtInput.tapLeafScript != null) {
          throw UnsupportedError(
              'Only single signature address type is supported for script path spending.');
        }
        SessionContext? sessionContext;

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

        List<DerivationPath>? derivationPathList;
        derivationPathList = psbtInput.tapBip32Derivation;
        for (DerivationPath derivationPath in derivationPathList!) {
          if (psbtInput.requiredSignature <= psbtInput.signedCount) {
            break;
          }
          for (KeyStore keyStore in keyStoreList) {
            if (!keyStore.hasSeed) {
              continue;
            }
            if (derivationPath.masterFingerprint ==
                keyStore.masterFingerprint) {
              // print("add signature to psbt ${keyStore.seed.passphrase}");
              keyStore.addSignatureToPsbtInput(
                  psbtInput, addressType, derivationPath.path, sigHash,
                  aggregatedPublicKey: psbtInput.muSig2AggregatedPublicKey!,
                  sessionContext: sessionContext);
              break;
            }
          }
        }
      }
    }
    return psbtObject.serialize();
  }

  String getCoordinatorBsms() {
    Bsms bsms = Bsms(
        coordinator: Coordinator(getAddress(0), Descriptor.parse(descriptor)));
    return bsms.serializeCoordinator();
  }

  Uint8List getAggregatedPublicKey(int addressIndex,
      {bool isChange = false, isXOnly = false}) {
    List<Uint8List> publicKeyList = _keyStoreList
        .map((keyStore) => keyStore.getPublicKeyBytes(addressIndex,
            isChange: isChange, isXOnly: false))
        .toList();

    publicKeyList.sort((a, b) {
      int len = a.length < b.length ? a.length : b.length;

      for (int i = 0; i < len; i++) {
        if (a[i] != b[i]) {
          return a[i].compareTo(b[i]);
        }
      }

      return a.length.compareTo(b.length);
    });
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

  Uint8List getMerkleRoot(int addressIndex, {bool isChange = false}) {
    final TapTree? tree = _tapTree;
    if (tree == null) {
      return Uint8List(0);
    }
    return tree.getMerkleRoot(addressIndex, isChange: isChange);
  }

  /// Number of siblings between the given policy's leaf and the merkle root.
  ///
  /// Each one costs 32 bytes in the control block, so fee estimation reads the
  /// real depth instead of guessing from the leaf count.
  int getMerklePathLength(int policyIndex, int addressIndex,
      {bool isChange = false}) {
    final TapTree? tree = _tapTree;
    if (tree == null) {
      throw StateError('No script policies found.');
    }
    return tree
        .getMerklePath(policyIndex, addressIndex, isChange: isChange)
        .length;
  }

  String getControlBlock(int policyIndex, int addressIndex,
      {bool isChange = false}) {
    if (_policyList.isEmpty) {
      throw StateError('No script policies found.');
    }
    if (policyIndex < 0 || policyIndex >= _policyList.length) {
      throw RangeError.range(
          policyIndex, 0, _policyList.length - 1, 'policyIndex');
    }

    final Uint8List internalKeyXOnly =
        getInternalKey(addressIndex, isChange: isChange);

    final TapTree tree = _tapTree!;
    final Uint8List merkleRoot =
        tree.getMerkleRoot(addressIndex, isChange: isChange);
    final Uint8List tweak =
        Hash.hashTapTweak('TapTweak', internalKeyXOnly, merkleRoot);
    final Uint8List outputKey =
        Ecc.pointAddScalar(internalKeyXOnly, tweak, true)!;

    final int parityBit = outputKey[0] == 0x03 ? 1 : 0;
    final int controlByte = 0xc0 | parityBit;

    final List<Uint8List> merklePath =
        tree.getMerklePath(policyIndex, addressIndex, isChange: isChange);

    final List<int> controlBlockBytes = [
      controlByte,
      ...internalKeyXOnly,
      ...merklePath.expand((e) => e),
    ];

    return Codec.encodeHex(Uint8List.fromList(controlBlockBytes));
  }

  static int _lexicographicCompare(Uint8List a, Uint8List b) {
    final minLen = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < minLen; i++) {
      if (a[i] != b[i]) {
        return a[i] < b[i] ? -1 : 1;
      }
    }
    if (a.length == b.length) return 0;
    return a.length < b.length ? -1 : 1;
  }
}
