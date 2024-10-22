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
    // if (_addressType.isMultisig) {
    //   throw Exception('Use MultsignatureVault or MultisignatureWallet.');
    // }
    if (BitcoinNetwork.currentNetwork.isTestnet !=
        AddressType.isTestnetVersion(_keyStore._extendedPublicKey.version)) {
      throw Exception('Network type mismatch.');
    }

    _descriptor = Descriptor.forSingleSignature(
        _addressType.scriptType.replaceAll("P2", "").toLowerCase(),
        _keyStore.extendedPublicKey.serialize(),
        _derivationPath.replaceAll("m/", ""),
        _keyStore.masterFingerprint);

    //generate address book
    int gapLimit = 20;
    List<Address> receiveList = [];
    List<Address> changeList = [];
    for (int i = 0; i < gapLimit; i++) {
      String receiveAddress =
          addressType.getAddress(_keyStore.getPublicKey(i, isChange: false));
      String receiveDerivationPath = '$derivationPath/0/$i';
      receiveList
          .add(Address(receiveAddress, receiveDerivationPath, i, false, 0));

      String changeAddress =
          addressType.getAddress(_keyStore.getPublicKey(i, isChange: true));
      String changeDerivationPath = '$derivationPath/1/$i';
      changeList.add(Address(changeAddress, changeDerivationPath, i, true, 0));
    }
  }

  /// Get the address of the given index.
  @override
  String getAddress(int addressIndex, {bool isChange = false}) {
    String pubkey = _keyStore.getPublicKey(addressIndex, isChange: isChange);
    return _addressType.getAddress(pubkey);
  }
}
