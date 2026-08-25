part of '../../coconut_lib.dart';

/// Represents a multisignature vault.
///
/// {@category Wallets and Keys}
class MultisignatureVault extends MultisignatureWalletBase {
  MultisignatureVault(super.requiredSignature, super.addressType,
      int accountIndex, super.derivationPath, super.keyStores);

  /// Create a multisignature vault from a list of keyStores.
  factory MultisignatureVault.fromKeyStoreList(
      List<KeyStore> keyStoreList, int requiredSignature,
      {AddressType? addressType, int accountIndex = 0}) {
    addressType ??= AddressType.p2wsh;
    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);

    return MultisignatureVault(requiredSignature, addressType, accountIndex,
        derivationPath, keyStoreList);
  }

  /// Create a multisignature vault from a list of seeds.
  factory MultisignatureVault.fromSeedList(
      List<Seed> seedList, int requiredSignature,
      {AddressType? addressType, int accountIndex = 0}) {
    addressType ??= AddressType.p2wsh;

    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);
    List<KeyStore> keyStores = [];
    for (var seed in seedList) {
      keyStores.add(
          KeyStore.fromSeed(seed, addressType, accountIndex: accountIndex));
    }
    return MultisignatureVault(requiredSignature, addressType, accountIndex,
        derivationPath, keyStores);
  }

  factory MultisignatureVault.fromCoordinatorBsms(String coordinator,
      {AddressType? addressType}) {
    addressType ??= AddressType.p2wsh;
    Bsms bsms = Bsms.parseCoordinator(coordinator);
    List<KeyStore> keyStores = [];
    Descriptor descriptor = bsms.coordinator!.descriptor;
    for (int i = 0; i < descriptor.totalSigner; i++) {
      ExtendedPublicKey extendedPublicKey =
          ExtendedPublicKey.parse(descriptor.getPublicKey(i));
      HDWallet hdWallet = HDWallet.fromPublicKey(
          extendedPublicKey.publicKey, extendedPublicKey.chainCode);
      KeyStore keyStore =
          KeyStore(descriptor.getFingerprint(i), hdWallet, extendedPublicKey);
      keyStores.add(keyStore);
    }

    return MultisignatureVault.fromKeyStoreList(
        keyStores, descriptor._requiredSignatures,
        addressType: descriptor._addressType);
  }

  /// Create a multisignature vault from a json string.
  factory MultisignatureVault.fromJson(String jsonStr) {
    final Map<String, dynamic> json =
        Codec._decodeJsonObject(jsonStr, name: 'MultisignatureVault JSON');
    List<KeyStore> keyStores = [];
    for (final dynamic keyStoreJson in Codec._readJsonField<List<dynamic>>(
        json, 'keyStores',
        name: 'MultisignatureVault JSON')) {
      if (keyStoreJson is! String) {
        throw const FormatException(
            'MultisignatureVault keyStores must contain JSON strings.');
      }
      keyStores.add(KeyStore.fromJson(keyStoreJson));
    }
    return MultisignatureVault.fromKeyStoreList(
        keyStores,
        Codec._readJsonField<int>(json, 'requiredSignature',
            name: 'MultisignatureVault JSON'),
        addressType: AddressType.getAddressTypeFromName(
            Codec._readJsonField<String>(json, 'addressTypeName',
                name: 'MultisignatureVault JSON')),
        accountIndex: 0);
  }

  void bindSeedToKeyStore(Seed seed, {int accountIndex = 0}) {
    KeyStore keyStoreFromSeed =
        KeyStore.fromSeed(seed, addressType, accountIndex: accountIndex);

    final int index = _keyStoreList.indexWhere(
        (keyStore) => keyStore.hasSamePublicIdentity(keyStoreFromSeed));
    if (index < 0) {
      throw StateError('Seed does not match any key store.');
    }

    final List<KeyStore> updatedKeyStores = List.of(_keyStoreList);
    updatedKeyStores[index] = keyStoreFromSeed;
    MultisignatureWalletBase._validateSignerSet(
        requiredSignature, updatedKeyStores);
    _keyStoreList[index] = keyStoreFromSeed;
  }

  /// Get Json string of the multisignature vault.
  String toJson() {
    return jsonEncode({
      "keyStores": keyStoreList.map((e) => e.toJson()).toList(),
      "requiredSignature": requiredSignature,
      "addressTypeName": addressType.name,
      "derivationPath": derivationPath
    });
  }
}
