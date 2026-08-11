part of '../../coconut_lib.dart';

abstract class TaprootWalletBase extends WalletBase {
  final List<KeyStore> _keyStoreList;
  final List<Policy> _policyList;
  final bool _isVault;

  /// Get the list of keyStores.
  List<KeyStore> get keyStoreList => List.unmodifiable(_keyStoreList);

  /// Check if this is a vault.
  bool get isVault => _isVault;

  /// Get the list of miniscripts.
  List<Policy> get policyList => List.unmodifiable(_policyList);

  /// @nodoc
  TaprootWalletBase(List<KeyStore> keyStoreList, List<Policy> policyList,
      String derivationPath, this._isVault)
      : _keyStoreList = List<KeyStore>.of(keyStoreList),
        _policyList = List<Policy>.of(policyList),
        super(AddressType.p2tr, derivationPath) {
    if (!_addressType.isTaproot) {
      throw Exception('Address type must be Taproot.');
    }

    _keyStoreList
        .sort((a, b) => a.masterFingerprint.compareTo(b.masterFingerprint));

    for (KeyStore keyStore in _keyStoreList) {
      if (NetworkType.currentNetworkType.isTestnet !=
          AddressType.isTestnetVersion(keyStore.extendedPublicKey.version)) {
        throw Exception('Network type mismatch.');
      }
    }

    // Check derivation path
    final segments = derivationPath.split('/');
    if (segments.length < 3 || segments[0] != 'm') {
      throw Exception('Invalid derivation path.');
    }
    final coinTypeSegment = segments[2];

    final coinType =
        int.tryParse(coinTypeSegment.replaceAll(RegExp(r"[h']"), ""));

    if (coinType == 1 && !NetworkType.currentNetworkType.isTestnet) {
      throw Exception('Invalid derivation path.');
    } else if (coinType == 0 && NetworkType.currentNetworkType.isTestnet) {
      throw Exception('Invalid derivation path.');
    }

    // Deterministic policy order: TapLeaf hash at receive index 0 (lexicographic).
    // Tie-break with miniscript when hashes match.
    if (_policyList.length > 1) {
      _policyList.sort((a, b) {
        final cmp = _lexicographicCompare(
          a.getTapleafHash(0, isChange: false),
          b.getTapleafHash(0, isChange: false),
        );
        if (cmp != 0) return cmp;
        return a.toMiniscript().compareTo(b.toMiniscript());
      });
    }

    _descriptor = Descriptor.forTaproot(_addressType, _keyStoreList,
        _policyList, _derivationPath.replaceAll("m/", ""));
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
      throw Exception('No key store found');
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
      throw Exception("Invalid derivation path (e.g., m/44'/0'/0'/0/0)");
    }

    if (!derivationPath.startsWith('$_derivationPath/')) {
      throw Exception("Derivation path does not match");
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
      throw Exception('Address Type is not matched.');
    }
    if (addressType != AddressType.p2tr) {
      throw Exception('Address type must be Taproot.');
    }
    if (psbtObject.inputs.length !=
        psbtObject.unsignedTransaction!.inputs.length) {
      throw Exception('Not enought psbt inputs or transaction inputs');
    }
    Set<KeyStore> targetkeyStoreSet = {};
    for (PsbtInput psbtInput in psbtObject.inputs) {
      if (psbtInput.tapLeafScript != null) {
        for (Policy policy in _policyList) {
          if (policy is InheritancePolicy) {
            targetkeyStoreSet.add(policy.beneficiaryKeyStore);
          }
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
      throw Exception('Address Type is not matched.');
    }

    if (addressType != AddressType.p2tr) {
      throw Exception('Address type must be Taproot.');
    }

    if (!hasPublicKeyInPsbt(psbt)) {
      throw Exception('No keyStore can sign to the PSBT.');
    }

    if (psbtObject.inputs.length !=
        psbtObject.unsignedTransaction!.inputs.length) {
      throw Exception('Not enought psbt inputs or transaction inputs');
    }

    if (this is! TaprootVault) {
      throw Exception('Taproot policy validation requires a vault.');
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
        for (DerivationPath derivationPath in derivationPathList!) {
          for (Policy policy in _policyList) {
            if (policy is InheritancePolicy) {
              if (policy.beneficiaryKeyStore.masterFingerprint ==
                  derivationPath.masterFingerprint) {
                policy.beneficiaryKeyStore.addSignatureToPsbtInput(
                    psbtInput, addressType, derivationPath.path, sigHash);
                break;
              }
            }
          }
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
          throw Exception(
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
    if (_policyList.isEmpty) {
      return Uint8List(0);
    }
    List<Uint8List> leafHashes = [];
    for (Policy policy in _policyList) {
      leafHashes.add(policy.getTapleafHash(addressIndex, isChange: isChange));
    }
    return _calculateMerkleRoot(leafHashes);
  }

  String getControlBlock(int policyIndex, int addressIndex,
      {bool isChange = false}) {
    if (_policyList.isEmpty) {
      throw Exception('No script policies found.');
    }
    if (policyIndex < 0 || policyIndex >= _policyList.length) {
      throw RangeError.range(
          policyIndex, 0, _policyList.length - 1, 'policyIndex');
    }

    final Uint8List internalKeyXOnly =
        getInternalKey(addressIndex, isChange: isChange);

    final List<Uint8List> leafHashes = _policyList
        .map(
            (policy) => policy.getTapleafHash(addressIndex, isChange: isChange))
        .toList();

    final Uint8List merkleRoot = _calculateMerkleRoot(leafHashes);
    final Uint8List tweak =
        Hash.hashTapTweak('TapTweak', internalKeyXOnly, merkleRoot);
    final Uint8List outputKey =
        Ecc.pointAddScalar(internalKeyXOnly, tweak, true)!;

    final int parityBit = outputKey[0] == 0x03 ? 1 : 0;
    final int controlByte = 0xc0 | parityBit;

    final List<Uint8List> merklePath = _buildTaprootMerklePath(
      leafHashes,
      policyIndex,
    );

    final List<int> controlBlockBytes = [
      controlByte,
      ...internalKeyXOnly,
      ...merklePath.expand((e) => e),
    ];

    return Codec.encodeHex(Uint8List.fromList(controlBlockBytes));
  }

  static List<Uint8List> _buildTaprootMerklePath(
      List<Uint8List> leafHashes, int targetIndex) {
    if (leafHashes.isEmpty) {
      return [];
    }
    if (leafHashes.length == 1) {
      return [];
    }

    List<Uint8List> level =
        leafHashes.map((e) => Uint8List.fromList(e)).toList();
    int index = targetIndex;
    final List<Uint8List> path = [];

    while (level.length > 1) {
      final List<Uint8List> next = [];
      int nextIndex = -1;

      for (int i = 0; i < level.length; i += 2) {
        if (i + 1 >= level.length) {
          // Odd node: promote to next level unchanged.
          next.add(level[i]);
          if (index == i) {
            nextIndex = next.length - 1;
          }
          continue;
        }

        final Uint8List left = level[i];
        final Uint8List right = level[i + 1];
        if (index == i) {
          path.add(Uint8List.fromList(right));
          nextIndex = next.length;
        } else if (index == i + 1) {
          path.add(Uint8List.fromList(left));
          nextIndex = next.length;
        }
        next.add(_tapBranchHash(left, right));
      }

      if (nextIndex < 0) {
        throw Exception('Failed to build Taproot merkle path');
      }

      level = next;
      index = nextIndex;
    }

    return path;
  }

  static Uint8List _calculateMerkleRoot(List<Uint8List> leafHashes) {
    // 단일 leaf인 경우 해당 leaf hash를 반환
    if (leafHashes.length == 1) {
      return leafHashes[0];
    }

    // Merkle tree 구성
    List<Uint8List> currentLevel =
        leafHashes.map((e) => Uint8List.fromList(e)).toList();

    while (currentLevel.length > 1) {
      final List<Uint8List> nextLevel = [];

      for (int i = 0; i < currentLevel.length; i += 2) {
        if (i + 1 == currentLevel.length) {
          // 홀수 개인 경우 마지막 요소를 그대로 전달
          nextLevel.add(currentLevel[i]);
          continue;
        }

        final left = currentLevel[i];
        final right = currentLevel[i + 1];
        nextLevel.add(_tapBranchHash(left, right));
      }

      currentLevel = nextLevel;
    }

    return currentLevel.first;
  }

  static Uint8List _tapBranchHash(Uint8List a, Uint8List b) {
    final compare = _lexicographicCompare(a, b);
    final first = compare <= 0 ? a : b;
    final second = compare <= 0 ? b : a;

    return Hash.taggedHash('TapBranch', _concat(first, second));
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

  static Uint8List _concat(Uint8List a, Uint8List b) {
    final out = Uint8List(a.length + b.length);
    out.setRange(0, a.length, a);
    out.setRange(a.length, a.length + b.length, b);
    return out;
  }
}
