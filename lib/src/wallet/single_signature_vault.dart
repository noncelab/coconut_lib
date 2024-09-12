part of '../../coconut_lib.dart';

/// Represents a single signature vault.
class SingleSignatureVault extends SingleSignatureWalletBase
    implements VaultFeature {
  SingleSignatureVault._(
      KeyStore keyStore, AddressType addressType, String derivationPath)
      : super(keyStore, addressType, derivationPath, true);

  /// Create a single signature vault from keystore.
  factory SingleSignatureVault.fromKeyStore(
      KeyStore keyStore, AddressType addressType,
      {int accountIndex = 0}) {
    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);
    return SingleSignatureVault._(keyStore, addressType, derivationPath);
  }

  /// Create a single signature vault from random entropy.
  factory SingleSignatureVault.random(AddressType addressType,
      {int mnemonicLength = 24, String passphrase = '', int accountIndex = 0}) {
    KeyStore keyStore = KeyStore.random(addressType,
        mnemonicLength: mnemonicLength,
        passphrase: passphrase,
        accountIndex: accountIndex);
    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);
    return SingleSignatureVault._(keyStore, addressType, derivationPath);
  }

  /// Create a single signature vault from mnemonic words.
  factory SingleSignatureVault.fromMnemonic(
      String mnemonicWords, AddressType addressType,
      {String passphrase = '', int accountIndex = 0}) {
    KeyStore keyStore = KeyStore.fromMnemonic(mnemonicWords, addressType,
        passphrase: passphrase, accountIndex: accountIndex);
    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);
    return SingleSignatureVault._(keyStore, addressType, derivationPath);
  }

  /// Create a single signature vault from seed.
  factory SingleSignatureVault.fromSeed(Seed seed, AddressType addressType,
      {int accountIndex = 0}) {
    KeyStore keyStore =
        KeyStore.fromSeed(seed, addressType, accountIndex: accountIndex);
    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);
    return SingleSignatureVault._(keyStore, addressType, derivationPath);
  }

  /// Create a single signature vault from hex entropy.
  factory SingleSignatureVault.fromEntropy(
      String entropy, AddressType addressType,
      {String passphrase = '', int accountIndex = 0}) {
    KeyStore keyStore = KeyStore.fromEntropy(entropy, addressType,
        passphrase: passphrase, accountIndex: accountIndex);
    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);
    return SingleSignatureVault._(keyStore, addressType, derivationPath);
  }

  @override
  bool canSignToPsbt(String psbt) {
    return keyStore.canSignToPsbt(psbt);
  }

  @override
  String addSignatureToPsbt(String psbt) {
    return keyStore.addSignatureToPsbt(psbt, addressType.isSegwit);
  }

  /// Get Json string of the single signature vault.
  String toJson() {
    return jsonEncode({
      "keyStore": keyStore.toJson(),
      "addressType": addressType.scriptType,
      "derivationPath": derivationPath
    });
  }

  /// Create a single signature vault from a json string.
  factory SingleSignatureVault.fromJson(String json) {
    Map<String, dynamic> map = jsonDecode(json);
    return SingleSignatureVault._(
        KeyStore.fromJson(map['keyStore']),
        AddressType.getAddressTypeFromScriptType(map['addressType']),
        map['derivationPath']);
  }
}
