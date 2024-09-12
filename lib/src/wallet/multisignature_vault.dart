part of '../../coconut_lib.dart';

/// Represents a multisignature vault.
class MultisignatureVault extends MultisignatureWalletBase
    implements VaultFeature {
  MultisignatureVault(int requiredSignature, AddressType addressType,
      int accountIndex, String derivationPath, List<KeyStore> keyStores)
      : super(requiredSignature, addressType, derivationPath, keyStores) {
    if (keyStores.length < requiredSignature) {
      throw Exception(
          'Required signature is greater than the number of keyStores.');
    }
  }

  /// Create a multisignature vault from a list of keyStores.
  factory MultisignatureVault.fromKeyStoreList(List<KeyStore> keyStoreList,
      int requiredSignature, AddressType addressType,
      {int accountIndex = 0}) {
    String derivationPath =
        WalletUtility.getDerivationPath(addressType, accountIndex);
    return MultisignatureVault(requiredSignature, addressType, accountIndex,
        derivationPath, keyStoreList);
  }

  /// Create a multisignature vault from a list of seeds.
  factory MultisignatureVault.fromSeedList(
      List<Seed> seedList, int requiredSignature, AddressType addressType,
      {int accountIndex = 0}) {
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

  @override
  bool canSignToPsbt(String psbt) {
    //TODO : implement
    return false;
  }

  @override
  String addSignatureToPsbt(String psbt) {
    //TODO : implement
    return " ";
  }

  //TODO : test
  /// Get Json string of the multisignature vault.
  String toJson() {
    return jsonEncode({
      "keyStores": keyStoreList.map((e) => e.toJson()).toList(),
      "requiredSignature": requiredSignature,
      "addressType": addressType.scriptType,
      "derivationPath": derivationPath
    });
  }

  //TODO : test
  /// Create a multisignature vault from a json string.
  factory MultisignatureVault.fromJson(String jsonStr) {
    Map<String, dynamic> json = jsonDecode(jsonStr);
    List<KeyStore> keyStores = [];
    for (var keyStoreJson in json['keyStores']) {
      keyStores.add(KeyStore.fromJson(jsonEncode(keyStoreJson)));
    }
    return MultisignatureVault.fromKeyStoreList(
        keyStores,
        json['requiredSignature'],
        AddressType.getAddressTypeFromScriptType(json['addressType']),
        accountIndex: 0);
  }
}
