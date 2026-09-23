part of '../../coconut_lib.dart';

/// Represents a Taproot wallet.
///
/// See the [Taproot script-path example](https://github.com/noncelab/coconut_lib/blob/main/doc/example/taproot_script_path.dart)
/// for inheritance-policy construction and signing.
///
/// {@category Wallets and Keys}
class TaprootWallet extends TaprootWalletBase {
  TaprootWallet._(List<KeyStore> keyStoreList, List<Policy> policyList,
      String derivationPath, {TapTree? tapTree})
      : super(_validateKeyStores(keyStoreList), _validatePolicies(policyList),
            derivationPath, false,
            tapTree: tapTree?.mapLeaves(_publicOnlyPolicy));

  static List<KeyStore> _validateKeyStores(List<KeyStore> keyStores) {
    return keyStores.map(KeyStore.publicOnly).toList(growable: false);
  }

  static List<Policy> _validatePolicies(List<Policy> policies) {
    return policies.map(_publicOnlyPolicy).toList(growable: false);
  }

  static Policy _publicOnlyPolicy(Policy policy) {
    if (policy is InheritancePolicy) {
      return InheritancePolicy(
          KeyStore.publicOnly(policy.beneficiaryKeyStore), policy.locktime);
    }
    if (policy is SingleSignaturePolicy) {
      return SingleSignaturePolicy(KeyStore.publicOnly(policy.keyStore));
    }
    if (policy is MultisignaturePolicy) {
      return MultisignaturePolicy(
          policy.keyStoreList.map(KeyStore.publicOnly).toList(),
          policy.requiredSignature);
    }
    throw ArgumentError('Unsupported Taproot policy type.');
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

    // The descriptor carries the tree with its shape; keep both.
    final TapTree? tapTree = descriptorObject.tapTree;

    return TaprootWallet._(keyStores, tapTree?.leaves ?? [], derivationPath,
        tapTree: tapTree);
  }

  /// Create a Taproot wallet whose script tree has the given shape.
  ///
  /// Use this instead of [TaprootWallet.fromKeyStoreList] when the grouping
  /// matters — `{A,{B,C}}` and `{{A,B},C}` are different addresses. Leaves are
  /// kept exactly where they are put.
  factory TaprootWallet.fromTapTree(
    List<KeyStore> keyStoreList,
    TapTree tapTree, {
    int accountIndex = 0,
  }) {
    String derivationPath =
        WalletUtility.getDerivationPath(AddressType.p2tr, accountIndex);
    return TaprootWallet._(keyStoreList, tapTree.leaves, derivationPath,
        tapTree: tapTree);
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
    final Map<String, dynamic> json =
        Codec._decodeJsonObject(jsonStr, name: 'TaprootWallet JSON');
    if (json['isVault'] == true) {
      throw const FormatException(
          'JSON is for TaprootVault; use TaprootVault.fromJson.');
    }
    final String path = Codec._readJsonField<String>(json, 'derivationPath',
        name: 'TaprootWallet JSON');
    final List<KeyStore> keyStores = [];
    for (final dynamic keyStoreJson in Codec._readJsonField<List<dynamic>>(
        json, 'keyStores',
        name: 'TaprootWallet JSON')) {
      if (keyStoreJson is! String) {
        throw const FormatException(
            'TaprootWallet keyStores must contain JSON strings.');
      }
      keyStores.add(KeyStore.fromJson(keyStoreJson));
    }

    final List<Policy> policies = [];
    final dynamic policiesJson = json['policies'];
    if (policiesJson != null) {
      if (policiesJson is! List<dynamic>) {
        throw const FormatException('TaprootWallet policies must be a list.');
      }
      for (final dynamic policyJson in policiesJson) {
        if (policyJson is! String) {
          throw const FormatException(
              'TaprootWallet policies must contain JSON strings.');
        }
        policies.add(Policy.fromJson(policyJson));
      }
    }

    final dynamic tapTreeJson = json['tapTree'];
    if (tapTreeJson != null && tapTreeJson is! String) {
      throw const FormatException('TaprootWallet tapTree must be a string.');
    }
    final TapTree? tapTree =
        tapTreeJson == null ? null : TapTree.parse(tapTreeJson as String);

    return TaprootWallet._(keyStores, policies, path, tapTree: tapTree);
  }

  /// Get Json string of the Taproot wallet.
  String toJson() {
    return jsonEncode({
      "keyStores": keyStoreList.map((e) => e.toJson()).toList(),
      "policies": policyList.map((e) => e.toJson()).toList(),
      // Without this a restored wallet would fall back to the default grouping.
      if (tapTree != null) "tapTree": tapTree!.toTreeExpression(),
      "addressTypeName": AddressType.p2tr.name,
      "derivationPath": derivationPath,
      "isVault": false,
    });
  }
}
