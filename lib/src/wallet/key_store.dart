part of '../../coconut_lib.dart';

/// Key Store is consist of fingerprint, exPub and seed.
class KeyStore {
  String _fingerprint;
  HDWallet _hdWallet;
  ExtendedPublicKey _extendedPublicKey;
  Seed? _seed;

  /// The fingerprint of the key store.
  String get fingerprint => _fingerprint;

  /// @nodoc
  HDWallet get hdWallet => _hdWallet;

  /// The extended public key of the key store.
  ExtendedPublicKey get extendedPublicKey => _extendedPublicKey;

  /// The seed of the key store.
  Seed get seed => _seed!;

  /// Check if the key store has seed.
  bool get hasSeed => _seed != null;

  /// @nodoc
  KeyStore(this._fingerprint, this._hdWallet, this._extendedPublicKey,
      [this._seed]);

  /// Create a key store from a seed.
  factory KeyStore.fromSeed(Seed seed, AddressType addressType,
      {int accountIndex = 0}) {
    bool isTestnet = BitcoinNetwork.currentNetwork.isTestnet;
    HDWallet rootWallet = HDWallet.fromRootSeed(seed.rootSeed);
    String fingerprint =
        Converter.bytesToHex(rootWallet.fingerprint).toUpperCase();

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
  factory KeyStore.fromMnemonic(String mnemonicWords, AddressType addressType,
      {String passphrase = '', int accountIndex = 0}) {
    Seed seed = Seed.fromMnemonic(mnemonicWords, passphrase: passphrase);

    return KeyStore.fromSeed(seed, addressType, accountIndex: accountIndex);
  }

  /// Create a key store from a random.
  factory KeyStore.random(AddressType addressType,
      {int mnemonicLength = 24, String passphrase = '', int accountIndex = 0}) {
    if (mnemonicLength <= 12 &&
        mnemonicLength >= 24 &&
        mnemonicLength % 3 != 0) {
      throw Exception('MnemonicLength is not valid.');
    }

    Seed seed =
        Seed.random(mnemonicLength: mnemonicLength, passphrase: passphrase);
    return KeyStore.fromSeed(seed, addressType, accountIndex: accountIndex);
  }

  /// Create a key store from a entropy.
  factory KeyStore.fromEntropy(String entropy, AddressType addressType,
      {String passphrase = '', int accountIndex = 0}) {
    Seed seed = Seed.fromHexadecimalEntropy(entropy, passphrase: passphrase);
    return KeyStore.fromSeed(seed, addressType, accountIndex: accountIndex);
  }

  /// Get the private key of the key store using index.
  String getPrivateKey(int index, {bool isChange = false}) {
    if (!hasSeed) throw Exception('No private key in this key store');
    int changeIndex = 0;
    if (isChange) changeIndex = 1;
    HDWallet child = _hdWallet.derive(changeIndex).derive(index);
    //print("priv : " + Converter.bytesToHex(child.privateKey!.toList()));
    return child.getMasterPrivateKey();
  }

//sign.
  String sign(String message, int addressIndex,
      {bool isChange = false, bool isDer = true}) {
    if (!hasSeed) throw Exception('No private key in this key store');
    int changeIndex = 0;
    if (isChange) changeIndex = 1;
    HDWallet child = _hdWallet.derive(changeIndex).derive(addressIndex);
    Uint8List signature = child.sign(Uint8List.fromList(HEX.decode(message)));
    String sig;
    if (isDer) {
      String r = Converter.bytesToHex(signature.sublist(0, 32));
      if (signature[0] & 0x80 != 0) {
        r = '00$r';
      }
      String rLength = Converter.decToHex(r.length ~/ 2);
      String s = Converter.bytesToHex(signature.sublist(32, 64));
      String sLength = Converter.decToHex(s.length ~/ 2);
      String rs = '02$rLength${r}02$sLength$s';
      sig = '30${Converter.decToHex(rs.length ~/ 2)}${rs}01';
    } else {
      sig = Converter.bytesToHex(signature);
    }

    return sig;
  }

//sign with derivation path.
  String signWithDerivationPath(String message, String derivationPath,
      {bool isDer = true}) {
    int index = int.parse(derivationPath.split('/').last);
    int changeIndex = int.parse(derivationPath.split('/')[4]);
    return sign(message, index, isChange: changeIndex == 1, isDer: isDer);
  }

  ///Check if the PSBT can be signed from this vault.
  bool canSignToPsbt(String psbt) {
    if (!hasSeed) {
      throw Exception('This vault does not have seed');
    }
    PSBT psbtObj = PSBT.parse(psbt);
    for (int i = 0; i < psbtObj.unsignedTransaction!.inputs.length; i++) {
      PsbtInput thisInput = psbtObj.inputs[i];
      // PsbtInput thisInput = psbtObj
      //     .getPsbtInput(psbtObj.unsignedTransaction!.inputs[i].transactionHash);

      if (thisInput.derivationPath!.parentFingerprint == fingerprint &&
          thisInput.derivationPath!.publicKey ==
              getPublicKeyWithDerivationPath(thisInput.derivationPath!.path)) {
        return true;
      }
    }
    return false;
  }

  ///add signature to PSBT if it's possible.
  String addSignatureToPsbt(String psbt, bool isSegwit) {
    if (!hasSeed) {
      throw Exception('This vault does not have seed');
    }
    PSBT psbtObject = PSBT.parse(psbt);
    if (canSignToPsbt(psbtObject.serialize()) == false) {
      throw Exception('Vault : This vault can not sign this PSBT');
    }
    for (int i = 0; i < psbtObject.unsignedTransaction!.inputs.length; i++) {
      PsbtInput thisInput = psbtObject.inputs[i];
      // PsbtInput thisInput = psbtObject.getPsbtInput(
      //     psbtObject.unsignedTransaction!.inputs[i].transactionHash);

      //sign
      String utxo = '';
      if (thisInput.witnessUtxo == null) {
        utxo = thisInput.previousTransaction!
            .outputs[psbtObject.unsignedTransaction!.inputs[i].index]
            .serialize();
      } else {
        utxo = thisInput.witnessUtxo!.serialize();
      }
      String sigHash =
          psbtObject.unsignedTransaction!.getSigHash(i, utxo, isSegwit);
      String publicKey =
          getPublicKeyWithDerivationPath(thisInput.derivationPath!.path);
      String signature =
          signWithDerivationPath(sigHash, thisInput.derivationPath!.path);
      if (validateSignatureWithDerivationPath(
          signature, sigHash, thisInput.derivationPath!.path)) {}
      psbtObject.addSignature(i, signature, publicKey);
    }

    return psbtObject.serialize();
  }

  /// Get the public key of the key store using index.
  String getPublicKey(int addressIndex, {bool isChange = false}) {
    int changeIndex = 0;
    if (isChange) changeIndex = 1;
    HDWallet child =
        _hdWallet.derive(changeIndex).derive(addressIndex).neutered();
    return HEX.encode((child.publicKey).toList());
  }

  /// Get the public key of the key store using derivation path.
  String getPublicKeyWithDerivationPath(String path) {
    List<String> pathList = path.split('/');
    int index = int.parse(pathList.last);
    int changeIndex = int.parse(pathList[pathList.length - 2]);
    HDWallet child = _hdWallet.derive(changeIndex).derive(index).neutered();
    return HEX.encode((child.publicKey).toList());
  }

  /// Validate the signatured from this key store.
  bool validateSignature(String signature, String message, int addressIndex,
      {bool isChange = false, bool isDer = true}) {
    int changeIndex = 0;
    if (isChange) changeIndex = 1;

    Uint8List sig = Converter.hexToBytes(signature);
    Uint8List msg = Converter.hexToBytes(message);

    HDWallet child = hdWallet.derive(changeIndex).derive(addressIndex);

    if (isDer) {
      //DER decoding
      int rLen = sig[3];
      Uint8List r = sig.sublist(4, 4 + rLen);
      if (r[0] == 0) r = r.sublist(1);
      int sLen = sig[4 + rLen + 1];
      Uint8List s = sig.sublist(4 + rLen + 2, 4 + rLen + 2 + sLen);
      Uint8List rs = Uint8List.fromList([...r, ...s]);

      return child.verify(msg, rs);
    } else {
      return child.verify(msg, sig);
    }
  }

  /// Validate the signatured from this key store with derivation path.
  bool validateSignatureWithDerivationPath(
      String signature, String message, String derivationPath,
      {bool isDer = true}) {
    int index = int.parse(derivationPath.split('/').last);
    int changeIndex = int.parse(derivationPath.split('/')[4]);
    return validateSignature(signature, message, index,
        isChange: changeIndex == 1, isDer: isDer);
  }

  ///@nodoc
  String toJson() {
    return jsonEncode({
      'fingerprint': _fingerprint,
      'hdWallet': _hdWallet.toJson(),
      'extendedPublicKey': _extendedPublicKey.serialize(),
      if (_seed != null) 'seed': _seed!.toJson()
    });
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

  ///@nodoc
  @override
  String toString() {
    return 'KeyStore{fingerprint: $_fingerprint, extendedPublicKey: $_extendedPublicKey}';
  }

  ///@nodoc
  @override
  bool operator ==(Object other) {
    if (other is KeyStore) {
      return _fingerprint == other._fingerprint &&
          _extendedPublicKey == other._extendedPublicKey;
    }
    return false;
  }

  ///@nodoc
  @override
  int get hashCode => toString().hashCode;
}
