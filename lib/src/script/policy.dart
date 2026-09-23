part of '../../coconut_lib.dart';

/// Base class for script policies.
///
/// {@category Scripts and Policies}
abstract class Policy {
  /// Convert the policy to a script.
  Script toScript(int addressIndex, {bool isChange = false});
  String toMiniscript();

  String toJson();

  /// Key stores that can produce signatures for this leaf.
  ///
  /// Everything that has to enumerate the signers of a script tree — PSBT
  /// global xpubs, TAP_BIP32_DERIVATION entries, signing — reads this instead
  /// of testing for a concrete policy type.
  List<KeyStore> get keyStoreList => const <KeyStore>[];

  /// Number of signatures this leaf requires.
  int get requiredSignature => 1;

  /// Swap a public-only signer for the seed-bearing [keyStore] of the same key.
  ///
  /// Returns `true` when this policy holds a matching signer. Vaults use it to
  /// bind a seed after restoring a watch-only policy.
  bool bindKeyStore(KeyStore keyStore) => false;

  Uint8List getTapleafHash(int addressIndex, {bool isChange = false}) {
    int version = 0xc0;
    // TapLeaf hash commits to the *raw* tapscript bytes (no length prefix).
    Uint8List scriptBytes = Codec.decodeHex(
        toScript(addressIndex, isChange: isChange).rawSerialize());
    Uint8List scriptSize;

    if (scriptBytes.length < 0xfd) {
      scriptSize = Uint8List.fromList([scriptBytes.length]);
    } else if (scriptBytes.length <= 0xffff) {
      scriptSize = Uint8List.fromList(
          [0xfd, scriptBytes.length & 0xff, (scriptBytes.length >> 8) & 0xff]);
    } else if (scriptBytes.length <= 0xffffffff) {
      scriptSize = Uint8List.fromList([
        0xfe,
        scriptBytes.length & 0xff,
        (scriptBytes.length >> 8) & 0xff,
        (scriptBytes.length >> 16) & 0xff,
        (scriptBytes.length >> 24) & 0xff
      ]);
    } else {
      throw ArgumentError("CompactSize encoding supports up to 4 bytes.");
    }

    Uint8List tapleafHash = Hash.taggedHash(
        "TapLeaf", Uint8List.fromList([version] + scriptSize + scriptBytes));
    return tapleafHash;
  }

  static Policy fromMiniscript(String miniscript) {
    // The second form is the spelling emitted before the argument order was
    // corrected; see InheritancePolicy.fromMiniscript.
    if (RegExp(r'^and_v\(v:after\(\d+\),pk\(.+\)\)$').hasMatch(miniscript) ||
        RegExp(r'^and_v\(v:pk\(.+\),after\(\d+\)\)$').hasMatch(miniscript)) {
      return InheritancePolicy.fromMiniscript(miniscript);
    } else if (RegExp(r'^pk\(.+\)$').hasMatch(miniscript)) {
      return SingleSignaturePolicy.fromMiniscript(miniscript);
    } else if (RegExp(r'^multi_a\(\d+,.+\)$').hasMatch(miniscript)) {
      return MultisignaturePolicy.fromMiniscript(miniscript);
    } else {
      throw Exception('Unsupported miniscript type.');
    }
  }

  /// Key origin expression of [keyStore] under the Taproot derivation path.
  static String _getKeyOriginExpression(KeyStore keyStore) {
    final KeyStore publicKeyStore = KeyStore.fromExtendedPublicKey(
        keyStore.extendedPublicKey.serialize(), keyStore.masterFingerprint);
    return TaprootWallet.fromKeyStoreList([publicKeyStore], [])
        .getKeyOriginExpression();
  }

  /// Restore the key store described by a single key origin expression.
  ///
  /// Validated before parsing so a malformed fragment raises a
  /// [FormatException] instead of a null-check error deeper in the parser.
  static KeyStore _parseKeyOriginExpression(String keyOriginExpression) {
    final String expression = keyOriginExpression.trim();
    if (!RegExp(r"^\[[0-9a-fA-F]{8}(?:/\d+[h']?)*\][a-zA-Z0-9]+(?:/.*)?$")
        .hasMatch(expression)) {
      throw FormatException(
          'Invalid key origin expression: $keyOriginExpression');
    }

    final TaprootWallet wallet =
        TaprootWallet.fromKeyOriginExpression(expression);
    if (wallet.keyStoreList.length > 1) {
      throw const FormatException(
          'Key origin expression must hold a single key.');
    }
    return wallet.keyStoreList[0];
  }

  /// Deserialize a policy from a JSON string.
  ///
  /// Supported formats:
  /// - `{ "type": "inheritance", ... }`
  /// - `{ "miniscript": "..." }` (legacy / compact form)
  static Policy fromJson(String jsonStr) {
    final Map<String, dynamic> map =
        Codec._decodeJsonObject(jsonStr, name: 'Policy JSON');

    final String? type = map['type'];
    if (type != null) {
      switch (type) {
        case 'inheritance':
          return InheritancePolicy.fromJson(jsonStr);
        case 'singleSignature':
          return SingleSignaturePolicy.fromJson(jsonStr);
        case 'multisignature':
          return MultisignaturePolicy.fromJson(jsonStr);
        default:
          throw FormatException('Unsupported policy type: $type');
      }
    }

    final String? miniscript = map['miniscript'];
    if (miniscript != null) {
      return Policy.fromMiniscript(miniscript);
    }

    throw const FormatException(
        'Invalid policy JSON: missing "type" or "miniscript".');
  }
}
