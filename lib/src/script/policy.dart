part of '../../coconut_lib.dart';

/// Base class for script policies.
abstract class Policy {
  /// Convert the policy to a script.
  Script toScript(int addressIndex, {bool isChange = false});
  String toMiniscript();

  String toJson();

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
    if (RegExp(r'^and_v\(v:pk\(.+\),after\(\d+\)\)$').hasMatch(miniscript)) {
      return InheritancePolicy.fromMiniscript(miniscript);
    } else {
      throw Exception('Unsupported miniscript type.');
    }
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
