part of '../../coconut_lib.dart';

/// Represents a Taproot vault with script path spending support.
class TaprootVault extends TaprootWalletBase {
  TaprootVault._(List<KeyStore> keyStoreList, List<Policy> policyList,
      String derivationPath)
      : super(keyStoreList, policyList, derivationPath, true);

  /// Create a Taproot vault from a list of keyStores.
  factory TaprootVault.fromKeyStoreList(
    List<KeyStore> keyStoreList,
    List<Policy> policyList, {
    int accountIndex = 0,
  }) {
    String derivationPath =
        WalletUtility.getDerivationPath(AddressType.p2tr, accountIndex);
    return TaprootVault._(keyStoreList, policyList, derivationPath);
  }

  /// Create a Taproot vault from a list of seeds.
  factory TaprootVault.fromSeedList(
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
    return TaprootVault._(keyStores, policyList, derivationPath);
  }

  factory TaprootVault.fromCoordinatorBsms(String coordinator,
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
    List<Policy> policies = [];
    for (String policy in descriptor.miniscriptList) {
      policies.add(Policy.fromMiniscript(policy));
    }

    return TaprootVault.fromKeyStoreList(keyStores, policies);
  }

  /// Add public nonce to the PSBT.
  String addPublicNonce(String psbt, {String extraInput = ''}) {
    if (addressType != AddressType.p2tr) {
      throw Exception("Only p2tr needs public nonce.");
    }
    if (!hasPublicKeyInPsbt(psbt)) {
      throw Exception('No keyStore can sign to the PSBT.');
    }
    if (keyStoreList.length == 1) {
      return psbt;
    }
    Psbt psbtObject = Psbt.parse(psbt);
    if (psbtObject.addressType != AddressType.p2tr) {
      throw Exception('Only p2tr needs public nonce.');
    }
    if (psbtObject.inputs.length !=
        psbtObject.unsignedTransaction!.inputs.length) {
      throw Exception('Not enought psbt inputs or transaction inputs');
    }
    psbtObject.validateTaprootPolicy(this);

    List<TransactionOutput> utxoList = [];
    for (int j = 0; j < psbtObject.unsignedTransaction!.inputs.length; j++) {
      utxoList.add(psbtObject.inputs[j].witnessUtxo!);
    }

    for (int inputIndex = 0;
        inputIndex < psbtObject.inputs.length;
        inputIndex++) {
      String sigHash = psbtObject.unsignedTransaction!
          .getTaprootSigHash(inputIndex, utxoList);
      PsbtInput psbtInput = psbtObject.inputs[inputIndex];
      for (DerivationPath derivationPath in psbtInput.tapBip32Derivation!) {
        for (KeyStore keyStore in keyStoreList) {
          if (keyStore.hasSeed &&
              derivationPath.masterFingerprint == keyStore.masterFingerprint) {
            keyStore.hasPublicKeyInPsbt(psbt);
            keyStore.addPublicNonceToPsbtInput(
                psbtInput, derivationPath.path, sigHash,
                extraInput: extraInput);
          }
        }
      }
    }
    return psbtObject.serialize();
  }

  /// Get Json string of the Taproot vault.
  String toJson() {
    return jsonEncode({
      "keyStores": keyStoreList.map((e) => e.toJson()).toList(),
      "policies": policyList.map((e) => e.toJson()).toList(),
      "addressTypeName": AddressType.p2tr.name,
      "derivationPath": derivationPath,
      "isVault": true,
    });
  }

  /// Create a Taproot vault from a json string.
  factory TaprootVault.fromJson(String jsonStr) {
    final Map<String, dynamic> json = jsonDecode(jsonStr);
    if (json['isVault'] == false) {
      throw Exception('JSON is for TaprootWallet; use TaprootWallet.fromJson');
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

    return TaprootVault._(keyStores, policies, path);
  }

  static TaprootVault fromDescriptor(String descriptor) {
    Descriptor descriptorObject = Descriptor.parse(descriptor);

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

    return TaprootVault._(keyStores, policies, derivationPath);
  }

  void bindSeedToKeyStore(Seed seed, {int accountIndex = 0}) {
    KeyStore keyStoreFromSeed =
        KeyStore.fromSeed(seed, addressType, accountIndex: accountIndex);

    final int index = keyStoreList.indexWhere(
        (keyStore) => keyStore.hasSamePublicIdentity(keyStoreFromSeed));
    if (index < 0) {
      throw StateError('Seed does not match any key store.');
    }
    keyStoreList[index] = keyStoreFromSeed;
  }

  void bindSeedToBeneficiaryKeyStore(Seed seed, {int accountIndex = 0}) {
    KeyStore keyStoreFromSeed =
        KeyStore.fromSeed(seed, AddressType.p2tr, accountIndex: accountIndex);
    for (Policy policy in policyList) {
      if (policy is InheritancePolicy) {
        if (policy.beneficiaryKeyStore
            .hasSamePublicIdentity(keyStoreFromSeed)) {
          policy.beneficiaryKeyStore = keyStoreFromSeed;
          return;
        }
      }
    }
    throw StateError('Seed does not match any beneficiary key store.');
  }

  Policy getSpendablePolicy() {
    for (Policy policy in policyList) {
      if (policy is InheritancePolicy) {
        if (policy.beneficiaryKeyStore.hasSeed) {
          return policy;
        }
      }
    }
    throw Exception('No spendable policy found.');
  }

  /// Display BSMS for multisig setup.
  String getSignerBsms(String description) {
    if (keyStoreList[0].hasSeed == false) {
      throw Exception('Use seed to create signer.');
    }

    KeyStore multisigKeyStore =
        // ignore: unnecessary_non_null_assertion
        KeyStore.fromSeed(keyStoreList[0].seed!, AddressType.p2tr);

    Bsms bsms = Bsms.fromSigner(
        multisigKeyStore.masterFingerprint,
        (WalletUtility.getDerivationPath(AddressType.p2tr, 0))
            .replaceAll("m/", ""),
        multisigKeyStore.extendedPublicKey.serialize(),
        description);
    return bsms.serializeSigner();
  }
}
