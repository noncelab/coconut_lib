part of '../../coconut_lib.dart';

/// Represents a single signature wallet.
class SingleSignatureWallet extends SingleSignatureWalletBase {
  /// Creates a new single signature wallet.
  SingleSignatureWallet(
      String masterFingerprint,
      HDWallet wallet,
      AddressType addressType,
      String derivationPath,
      ExtendedPublicKey extendedPublicKey)
      : super(
            KeyStore.publicOnly(
                KeyStore(masterFingerprint, wallet, extendedPublicKey)),
            addressType,
            derivationPath,
            false);

  /// Create a single signature wallet from descriptor.
  factory SingleSignatureWallet.fromDescriptor(String descriptor,
      {bool ignoreChecksum = false}) {
    Descriptor descriptorObject =
        Descriptor.parse(descriptor, ignoreChecksum: ignoreChecksum);
    AddressType addressType;
    if (descriptorObject.scriptType == "sh-wpkh") {
      addressType = AddressType.p2wpkhInP2sh;
    } else {
      addressType = descriptorObject._addressType;
    }

    if (addressType.isMultisignature) {
      throw Exception(
          '${addressType.getAddress} is multisig script. Use MultsignatureVault Class.');
    }

    ExtendedPublicKey extendedPublicKey =
        ExtendedPublicKey.parse(descriptorObject.getPublicKey(0));
    HDWallet wallet = HDWallet.fromPublicKey(
        extendedPublicKey.publicKey, extendedPublicKey.chainCode);
    return SingleSignatureWallet(descriptorObject.getFingerprint(0), wallet,
        addressType, descriptorObject.getDerivationPath(0), extendedPublicKey);
  }

  factory SingleSignatureWallet.fromExtendedPublicKey(AddressType addressType,
      String extendedPublicKey, String masterFingerprint) {
    if (addressType.isMultisignature) {
      throw Exception('${addressType.getAddress} is multisig script.');
    }
    String derivationPath = WalletUtility.getDerivationPath(addressType, 0);
    ExtendedPublicKey extendedPublicKeyObject =
        ExtendedPublicKey.parse(extendedPublicKey);
    HDWallet wallet = HDWallet.fromPublicKey(
        extendedPublicKeyObject.publicKey, extendedPublicKeyObject.chainCode);
    wallet.depth = derivationPath.split('/').length - 1;
    return SingleSignatureWallet(masterFingerprint, wallet, addressType,
        derivationPath, extendedPublicKeyObject);
  }

  /// Parse the single signature wallet from json string.
  factory SingleSignatureWallet.fromJson(String jsonStr) {
    Map<String, dynamic> json = jsonDecode(jsonStr);
    return SingleSignatureWallet.fromDescriptor(json['descriptor']);
  }

  factory SingleSignatureWallet.fromCryptoAccountPayload(
      Map<String, dynamic> payload) {
    String masterFingerprint = Converter.decToHexWithPadding(payload['1'], 8);
    for (var item in payload['2']) {
      if (item['6']['1'][0] == 84) {
        // p2wpkh
        String publicKey =
            Codec.encodeHex(Uint8List.fromList(item['3'].cast<int>()));
        String chainCode =
            Codec.encodeHex(Uint8List.fromList(item['4'].cast<int>()));
        String parentFingerprint = Converter.decToHexWithPadding(item['8'], 8);
        List<dynamic> raw = item['6']['1'];
        final buffer = StringBuffer('m');
        for (int i = 0; i < raw.length; i += 2) {
          final index = raw[i];
          final hardened = raw[i + 1] == true;
          buffer.write('/');
          buffer.write(index);
          if (hardened) {
            buffer.write("'");
          }
        }
        String derivationPath = buffer.toString();

        final regex = RegExp(r"m(/\d+'?){3}");
        if (!regex.hasMatch(derivationPath)) {
          throw FormatException("Invalid BIP derivation path");
        }

        final segments = derivationPath.split('/');
        if (segments.length < 3) {
          throw FormatException("Too short to determine network");
        }

        final coinTypeStr = segments[2];
        final coinType = int.tryParse(coinTypeStr.replaceAll("'", ''));
        if (coinType == null) {
          throw FormatException("Invalid coin type");
        }

        bool isTestnet = coinType == 1;
        if (isTestnet != NetworkType.currentNetworkType.isTestnet) {
          throw FormatException("Invalid network type");
        }

        HDWallet wallet = HDWallet.fromPublicKey(
            Codec.decodeHex(publicKey), Codec.decodeHex(chainCode));
        wallet.depth = segments.length - 1;
        ExtendedPublicKey extendedPublicKey = ExtendedPublicKey.fromHdWallet(
            wallet,
            !NetworkType.currentNetworkType.isTestnet
                ? AddressType.p2wpkh.versionForMainnet
                : AddressType.p2wpkh.versionForTestnet,
            Codec.decodeHex(parentFingerprint));
        return SingleSignatureWallet(masterFingerprint, wallet,
            AddressType.p2wpkh, derivationPath, extendedPublicKey);
      } else {
        continue;
      }
    }
    throw Exception('Unsupported address type');
  }

  /// Get Json string of the single signature wallet.
  String toJson() {
    return jsonEncode({'descriptor': descriptor});
  }
}
