part of '../../coconut_lib.dart';

/// Represents a Taproot wallet.
class TaprootWallet extends TaprootWalletBase {
  TaprootWallet._(List<KeyStore> keyStoreList, List<Policy> policyList,
      String derivationPath)
      : super(_validateKeyStores(keyStoreList), _validatePolicies(policyList),
            derivationPath, false);

  static List<KeyStore> _validateKeyStores(List<KeyStore> keyStores) {
    return keyStores.map(KeyStore.publicOnly).toList(growable: false);
  }

  static List<Policy> _validatePolicies(List<Policy> policies) {
    return policies.map((policy) {
      if (policy is InheritancePolicy) {
        return InheritancePolicy(
            KeyStore.publicOnly(policy.beneficiaryKeyStore), policy.locktime);
      }
      throw ArgumentError('Unsupported Taproot policy type.');
    }).toList(growable: false);
  }

  /// Create a Taproot wallet from a list of keyStores.
  factory TaprootWallet.fromKeyStoreList(
    List<KeyStore> keyStoreList,
    List<Policy> policyList, {
    int accountIndex = 0,
  }) {
    String derivationPath =
        WalletUtility.getDerivationPath(AddressType.p2tr, accountIndex);

    return TaprootWallet._(keyStoreList, policyList, derivationPath);
  }

  /// Create a Taproot wallet from a list of seeds.
  factory TaprootWallet.fromSeedList(
    List<Seed> seedList,
    List<Policy> policyList, {
    int accountIndex = 0,
  }) {
    String derivationPath =
        WalletUtility.getDerivationPath(AddressType.p2tr, accountIndex);
    List<KeyStore> keyStores = [];
    for (var seed in seedList) {
      keyStores.add(KeyStore.fromSeed(seed, AddressType.p2tr,
          accountIndex: accountIndex));
    }
    return TaprootWallet._(keyStores, policyList, derivationPath);
  }

  /// Create a Taproot wallet from descriptor.
  factory TaprootWallet.fromDescriptor(String descriptor,
      {bool ignoreChecksum = false}) {
    Descriptor descriptorObject =
        Descriptor.parse(descriptor, ignoreChecksum: ignoreChecksum);

    if (descriptorObject.scriptType != 'tr') {
      throw Exception('Descriptor is not for Taproot address type.');
    }

    List<KeyStore> keyStores = [];
    String derivationPath = descriptorObject.getDerivationPath(0);

    for (int i = 0; i < descriptorObject.totalSigner; i++) {
      String fingerprint = descriptorObject.getFingerprint(i);
      ExtendedPublicKey extendedPublicKey =
          ExtendedPublicKey.parse(descriptorObject.getPublicKey(i));
      HDWallet wallet = HDWallet.fromPublicKey(
          extendedPublicKey.publicKey, extendedPublicKey.chainCode);
      if (derivationPath != descriptorObject.getDerivationPath(i)) {
        throw Exception('Derivation Path is not same.');
      }

      KeyStore keyStore = KeyStore(fingerprint, wallet, extendedPublicKey);
      keyStores.add(keyStore);
    }

    // Parse policies from miniscript list if available
    List<Policy> policies = [];
    if (descriptorObject.miniscriptList.isNotEmpty &&
        descriptorObject.miniscriptList.length > 0) {
      for (String miniscript in descriptorObject.miniscriptList) {
        policies.add(Policy.fromMiniscript(miniscript));
      }
    }

    return TaprootWallet._(keyStores, policies, derivationPath);
  }

  factory TaprootWallet.fromKeyOriginExpression(String keyOriginExpression) {
    RegExpMatch match =
        RegExp(r'\[(.+)\](.+)').firstMatch(keyOriginExpression)!;
    String derivationPath =
        'm/${match.group(1)!.split('/').sublist(1).join('/')}'
            .replaceAll('h', "'");
    String? fingerprint = match.group(1)!.split('/')[0];
    String? extendedPublicKey = match.group(2)!.split('/')[0];

    ExtendedPublicKey extendedPublicKeyObject =
        ExtendedPublicKey.parse(extendedPublicKey);
    HDWallet wallet = HDWallet.fromPublicKey(
        extendedPublicKeyObject.publicKey, extendedPublicKeyObject.chainCode);
    return TaprootWallet._(
        [KeyStore(fingerprint, wallet, extendedPublicKeyObject)],
        [],
        derivationPath);
  }

  /// Create a Taproot wallet from a json string.
  factory TaprootWallet.fromJson(String jsonStr) {
    final Map<String, dynamic> json = jsonDecode(jsonStr);
    if (json['isVault'] == true) {
      throw Exception('JSON is for TaprootVault; use TaprootVault.fromJson');
    }
    final String path = json['derivationPath'] as String;
    final List<KeyStore> keyStores = [];
    for (final dynamic keyStoreJson in json['keyStores'] as List<dynamic>) {
      keyStores.add(KeyStore.fromJson(keyStoreJson as String));
    }

    final List<Policy> policies = [];
    final dynamic policiesJson = json['policies'];
    if (policiesJson != null) {
      for (final dynamic policyJson in policiesJson as List<dynamic>) {
        policies.add(Policy.fromJson(policyJson as String));
      }
    }

    return TaprootWallet._(keyStores, policies, path);
  }

  /// Get Json string of the Taproot wallet.
  String toJson() {
    return jsonEncode({
      "keyStores": keyStoreList.map((e) => e.toJson()).toList(),
      "policies": policyList.map((e) => e.toJson()).toList(),
      "addressTypeName": AddressType.p2tr.name,
      "derivationPath": derivationPath,
      "isVault": false,
    });
  }
}
