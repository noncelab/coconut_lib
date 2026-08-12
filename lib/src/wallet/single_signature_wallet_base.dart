part of '../../coconut_lib.dart';

/// Represents a common member of single signature wallet and vault.
abstract class SingleSignatureWalletBase extends WalletBase {
  final KeyStore _keyStore;
  final bool _isVault;
  bool get isVault => _isVault;

  /// Get the keystore.
  KeyStore get keyStore => _keyStore;

  /// @nodoc
  SingleSignatureWalletBase(this._keyStore, AddressType _addressType,
      String _derivationPath, this._isVault)
      : super(_addressType, _derivationPath) {
    if (!_isVault) {
      KeyStore._ensureWatchOnly([_keyStore]);
    }
    if (NetworkType.currentNetworkType.isTestnet !=
        AddressType.isTestnetVersion(_keyStore._extendedPublicKey.version)) {
      throw WalletException(
          WalletErrorCode.networkMismatch, 'Network type mismatch.');
    }
    // check derivation path
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

    _descriptor = Descriptor.forSingleSignature(
        _addressType, _keyStore, _derivationPath.replaceAll("m/", ""));
  }

  /// Get the address of the given index.
  @override
  String getAddress(int addressIndex, {bool isChange = false}) {
    String pubkey;
    pubkey = _keyStore.getPublicKey(addressIndex, isChange: isChange);
    return _addressType.getAddress(pubkey);
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

    String pubkey = _keyStore.getPublicKey(
        WalletUtility.getAccountIndexFromDerivationPath(derivationPath),
        isChange: WalletUtility.isChangeFromDerivationPath(derivationPath));
    return _addressType.getAddress(pubkey);
  }

  @override
  String getKeyOriginExpression() {
    return Descriptor.getKeyOriginExpression(keyStore, derivationPath);
  }

  @override
  bool hasPublicKeyInPsbt(String psbt) {
    return keyStore.hasPublicKeyInPsbt(psbt);
  }

  @override
  String addSignatureToPsbt(String psbt) {
    Psbt psbtObject = Psbt.parse(psbt);
    if (psbtObject.addressType != addressType) {
      throw PsbtException(
          PsbtErrorCode.policyMismatch, 'PSBT address type does not match.');
    }

    if (psbtObject.inputs.length !=
        psbtObject.unsignedTransaction!.inputs.length) {
      throw PsbtException(PsbtErrorCode.transactionInputMismatch,
          'PSBT input count does not match the unsigned transaction.');
    }

    for (int inputIndex = 0;
        inputIndex < psbtObject.inputs.length;
        inputIndex++) {
      PsbtInput input = psbtObject.inputs[inputIndex];
      TransactionOutput utxo = input.witnessUtxo!;
      late String sigHash;
      List<DerivationPath>? derivationPathList;
      if (!addressType.isTaproot) {
        derivationPathList = input.bip32Derivation;
        sigHash = psbtObject.unsignedTransaction!
            .getSigHash(inputIndex, utxo, addressType);
      } else {
        derivationPathList = input.tapBip32Derivation;

        List<TransactionOutput> utxoList = [];
        for (int j = 0;
            j < psbtObject.unsignedTransaction!.inputs.length;
            j++) {
          utxoList.add(psbtObject.inputs[j].witnessUtxo!);
        }
        sigHash = psbtObject.unsignedTransaction!.getTaprootSigHash(
            inputIndex, utxoList,
            hashType: input.taprootSighashType);
      }

      for (DerivationPath derivationPath in derivationPathList!) {
        if (derivationPath.masterFingerprint == keyStore.masterFingerprint) {
          keyStore.addSignatureToPsbtInput(
            input,
            addressType,
            derivationPath.path,
            sigHash,
          );
          break;
        }
      }
    }
    return psbtObject.serialize();
  }
}
