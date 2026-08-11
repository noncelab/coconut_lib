part of '../../coconut_lib.dart';

/// Represents a multisignature wallet.
class MultisignatureWallet extends MultisignatureWalletBase {
  /// @nodoc
  MultisignatureWallet(int requiredSignature, AddressType addressType,
      String derivationPath, List<KeyStore> keyStores)
      : super(requiredSignature, addressType, derivationPath,
            _validateKeyStores(keyStores));

  static List<KeyStore> _validateKeyStores(List<KeyStore> keyStores) {
    return keyStores.map(KeyStore.publicOnly).toList(growable: false);
  }

  /// Create a multisignature wallet from descriptor.
  factory MultisignatureWallet.fromDescriptor(String descriptor,
      {bool ignoreChecksum = false}) {
    Descriptor descriptorObject =
        Descriptor.parse(descriptor, ignoreChecksum: ignoreChecksum);
    AddressType addressType;
    if (descriptorObject.scriptType == "sh-wpkh") {
      addressType = AddressType.p2wpkhInP2sh;
    } else {
      addressType = descriptorObject._addressType;
    }

    if (!addressType.isMultisignature) {
      throw Exception('Use ${addressType.getAddress} is not multisig script.');
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

    return MultisignatureWallet(descriptorObject._requiredSignatures,
        addressType, descriptorObject.getDerivationPath(0), keyStores);
  }

  /// Parse the multisignature wallet from json string.
  factory MultisignatureWallet.fromJson(String jsonStr) {
    final Map<String, dynamic> json =
        Codec._decodeJsonObject(jsonStr, name: 'MultisignatureWallet JSON');
    return MultisignatureWallet.fromDescriptor(Codec._readJsonField<String>(
        json, 'descriptor',
        name: 'MultisignatureWallet JSON'));
  }

  /// Get Json string of the multisignature wallet.
  String toJson() {
    return jsonEncode({'descriptor': descriptor});
  }
}
