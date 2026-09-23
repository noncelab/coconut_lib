part of '../../coconut_lib.dart';

/// Taproot script-path policy requiring a single signature.
///
/// The leaf is the minimal tapscript `<x-only pubkey> OP_CHECKSIG`, which is
/// what the `pk()` miniscript fragment compiles to. Use it to place a key in
/// the script tree instead of (or in addition to) the internal key.
///
/// {@category Scripts and Policies}
class SingleSignaturePolicy extends Policy {
  /// Key store allowed to spend through this leaf.
  KeyStore keyStore;

  SingleSignaturePolicy(this.keyStore) : super();

  /// Create a policy from a single-signature Taproot descriptor.
  factory SingleSignaturePolicy.fromDescriptor(String descriptor) {
    Descriptor parsedDescriptor = Descriptor.parse(descriptor);
    if (!parsedDescriptor._addressType.isTaproot) {
      throw Exception('Only Taproot address type is supported.');
    } else if (parsedDescriptor._keyOriginExpressionList.length > 1) {
      throw Exception('Only single signature address type is supported.');
    } else if (parsedDescriptor.miniscriptList.isNotEmpty) {
      throw Exception('Taproot script is not supported.');
    }

    TaprootWallet wallet = TaprootWallet.fromDescriptor(descriptor);
    if (wallet.keyStoreList.length > 1) {
      throw Exception('Only single signature address type is supported.');
    }
    return SingleSignaturePolicy(wallet.keyStoreList[0]);
  }

  @override
  List<KeyStore> get keyStoreList => List.unmodifiable([keyStore]);

  @override
  bool bindKeyStore(KeyStore keyStore) {
    if (!this.keyStore.hasSamePublicIdentity(keyStore)) {
      return false;
    }
    this.keyStore = keyStore;
    return true;
  }

  @override
  Script toScript(int addressIndex, {bool isChange = false}) {
    Uint8List publicKey = keyStore.getPublicKeyBytes(addressIndex,
        isChange: isChange, isXOnly: true);

    return Script([
      publicKey,
      ScriptOperationCode.getHex('OP_CHECKSIG'),
    ]);
  }

  @override
  String toMiniscript() {
    return 'pk(${Policy._getKeyOriginExpression(keyStore)})';
  }

  @override
  String toJson() {
    return jsonEncode({
      'type': 'singleSignature',
      // Keep the same JSON convention as the rest of the library:
      // nested objects are stored as JSON strings.
      'keyStore': keyStore.toJson(),
      // Convenience for debugging / legacy parsing
      'miniscript': toMiniscript(),
    });
  }

  factory SingleSignaturePolicy.fromJson(String jsonStr) {
    final Map<String, dynamic> map =
        Codec._decodeJsonObject(jsonStr, name: 'SingleSignaturePolicy JSON');
    final String keyStoreJson = Codec._readJsonField<String>(map, 'keyStore',
        name: 'SingleSignaturePolicy JSON');

    return SingleSignaturePolicy(KeyStore.fromJson(keyStoreJson));
  }

  static Policy fromMiniscript(String miniscript) {
    final RegExpMatch? match = RegExp(r'^pk\((.+)\)$').firstMatch(miniscript);
    if (match == null) {
      throw FormatException('Unsupported single signature miniscript.');
    }

    return SingleSignaturePolicy(
        Policy._parseKeyOriginExpression(match.group(1)!));
  }
}
