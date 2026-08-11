part of '../../coconut_lib.dart';

/// Represents a single signature vault.
class SingleSignatureVault extends SingleSignatureWalletBase {
  SingleSignatureVault._(
      KeyStore keyStore, AddressType addressType, String derivationPath)
      : super(keyStore, addressType, derivationPath, true) {
    if (addressType == AddressType.p2sh || addressType == AddressType.p2wsh) {
      throw Exception("Address type is not for single signature vault");
    }
  }

  /// Create a single signature vault from keystore.
  factory SingleSignatureVault.fromKeyStore(KeyStore keyStore,
      {AddressType? addressType, int accountIndex = 0}) {
    addressType ??= AddressType.p2wpkh;
    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);
    return SingleSignatureVault._(keyStore, addressType, derivationPath);
  }

  /// Create a single signature vault from random entropy.
  factory SingleSignatureVault.random({
    AddressType? addressType,
    int mnemonicLength = 24,
    Uint8List? passphrase,
    int accountIndex = 0,
  }) {
    addressType ??= AddressType.p2wpkh;
    KeyStore keyStore = KeyStore.random(addressType,
        mnemonicLength: mnemonicLength,
        passphrase: passphrase,
        accountIndex: accountIndex);
    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);
    return SingleSignatureVault._(keyStore, addressType, derivationPath);
  }

  /// Create a single signature vault from mnemonic words.
  factory SingleSignatureVault.fromMnemonic(Uint8List mnemonicWords,
      {AddressType? addressType, Uint8List? passphrase, int accountIndex = 0}) {
    addressType ??= AddressType.p2wpkh;
    KeyStore keyStore = KeyStore.fromMnemonic(mnemonicWords, addressType,
        passphrase: passphrase, accountIndex: accountIndex);
    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);
    return SingleSignatureVault._(keyStore, addressType, derivationPath);
  }

  /// Create a single signature vault from seed.
  factory SingleSignatureVault.fromSeed(Seed seed,
      {AddressType? addressType, int accountIndex = 0}) {
    addressType ??= AddressType.p2wpkh;
    KeyStore keyStore =
        KeyStore.fromSeed(seed, addressType, accountIndex: accountIndex);
    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);
    return SingleSignatureVault._(keyStore, addressType, derivationPath);
  }

  /// Create a single signature vault from hex entropy.
  factory SingleSignatureVault.fromEntropy(Uint8List entropy,
      {AddressType? addressType, Uint8List? passphrase, int accountIndex = 0}) {
    addressType ??= AddressType.p2wpkh;
    KeyStore keyStore = KeyStore.fromEntropy(entropy, addressType,
        passphrase: passphrase, accountIndex: accountIndex);
    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);
    return SingleSignatureVault._(keyStore, addressType, derivationPath);
  }

  /// Create a single signature vault from a json string.
  factory SingleSignatureVault.fromJson(String json) {
    final Map<String, dynamic> map =
        Codec._decodeJsonObject(json, name: 'SingleSignatureVault JSON');
    return SingleSignatureVault._(
        KeyStore.fromJson(Codec._readJsonField<String>(map, 'keyStore',
            name: 'SingleSignatureVault JSON')),
        AddressType.getAddressTypeFromName(Codec._readJsonField<String>(
            map, 'addressTypeName', name: 'SingleSignatureVault JSON')),
        Codec._readJsonField<String>(map, 'derivationPath',
            name: 'SingleSignatureVault JSON'));
  }

  /// Display BSMS for multisig setup.
  String getSignerBsms(AddressType targetAddressType, String description) {
    if (keyStore.hasSeed == false) {
      throw Exception('Use seed to create signer.');
    }
    if (!(targetAddressType.isMultisignature ||
        targetAddressType == AddressType.p2tr)) {
      throw Exception('Use multisignature or p2tr address type.');
    }

    KeyStore multisigKeyStore =
        // ignore: unnecessary_non_null_assertion
        KeyStore.fromSeed(keyStore.seed!, targetAddressType);

    Bsms bsms = Bsms.fromSigner(
        multisigKeyStore.masterFingerprint,
        (WalletUtility.getDerivationPath(targetAddressType, 0))
            .replaceAll("m/", ""),
        multisigKeyStore.extendedPublicKey.serialize(),
        description);
    return bsms.serializeSigner();
  }

  /// Get Json string of the single signature vault.
  String toJson() {
    return jsonEncode({
      "keyStore": keyStore.toJson(),
      "addressTypeName": addressType.name,
      "derivationPath": derivationPath
    });
  }
}
