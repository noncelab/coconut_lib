part of '../../coconut_lib.dart';

/// Taproot script-path policy requiring k-of-n signatures.
///
/// The leaf is a BIP-342 `multi_a` tapscript — each key is checked in turn with
/// OP_CHECKSIGADD and the accumulated count is compared against the threshold:
///
///     <pk1> OP_CHECKSIG <pk2> OP_CHECKSIGADD ... <pkn> OP_CHECKSIGADD
///     <k> OP_NUMEQUAL
///
/// Key order is significant: it is preserved exactly as given so the script and
/// the `multi_a()` miniscript always describe the same leaf. Legacy
/// OP_CHECKMULTISIG is not used — it is disabled in tapscript; see
/// [MultisignatureScript] for the P2WSH form.
///
/// {@category Scripts and Policies}
class MultisignaturePolicy extends Policy {
  /// Largest threshold that fits in a single OP_1..OP_16 push.
  static const int maxRequiredSignature = 16;

  final List<KeyStore> _keyStoreList;
  final int _requiredSignature;

  /// Key stores participating in this leaf, in script order.
  @override
  List<KeyStore> get keyStoreList => List.unmodifiable(_keyStoreList);

  /// Number of signatures the leaf requires.
  @override
  int get requiredSignature => _requiredSignature;

  /// Number of key stores in this leaf.
  int get totalSigner => _keyStoreList.length;

  MultisignaturePolicy(List<KeyStore> keyStoreList, int requiredSignature)
      : _keyStoreList = List<KeyStore>.of(keyStoreList),
        _requiredSignature = requiredSignature,
        super() {
    _validate(_keyStoreList, _requiredSignature);
  }

  static void _validate(List<KeyStore> keyStoreList, int requiredSignature) {
    if (keyStoreList.isEmpty) {
      throw ArgumentError.value(
          keyStoreList, 'keyStoreList', 'At least one key store is required.');
    }
    if (requiredSignature < 1 || requiredSignature > keyStoreList.length) {
      throw RangeError.range(requiredSignature, 1, keyStoreList.length,
          'requiredSignature', 'Required signatures must be 1..n.');
    }
    if (requiredSignature > maxRequiredSignature) {
      throw RangeError.range(requiredSignature, 1, maxRequiredSignature,
          'requiredSignature', 'Threshold must fit in a single opcode.');
    }

    final Set<String> distinctKeys = keyStoreList
        .map((keyStore) => keyStore.extendedPublicKey.serialize())
        .toSet();
    if (distinctKeys.length != keyStoreList.length) {
      throw ArgumentError.value(
          keyStoreList, 'keyStoreList', 'Duplicate public key.');
    }
  }

  /// Create a policy from a multisignature Taproot descriptor.
  ///
  /// The descriptor supplies the cosigner keys; [requiredSignature] supplies
  /// the threshold, which a `tr()` descriptor's key list does not carry.
  factory MultisignaturePolicy.fromDescriptor(
      String descriptor, int requiredSignature) {
    Descriptor parsedDescriptor = Descriptor.parse(descriptor);
    if (!parsedDescriptor._addressType.isTaproot) {
      throw Exception('Only Taproot address type is supported.');
    } else if (parsedDescriptor.miniscriptList.isNotEmpty) {
      throw Exception('Taproot script is not supported.');
    }

    TaprootWallet wallet = TaprootWallet.fromDescriptor(descriptor);
    return MultisignaturePolicy(wallet.keyStoreList, requiredSignature);
  }

  @override
  bool bindKeyStore(KeyStore keyStore) {
    for (int i = 0; i < _keyStoreList.length; i++) {
      if (_keyStoreList[i].hasSamePublicIdentity(keyStore)) {
        _keyStoreList[i] = keyStore;
        return true;
      }
    }
    return false;
  }

  /// Signers of a `multi_a` leaf, in script order, or `null` for other leaves.
  ///
  /// Spending code reads the leaf straight from the witness or the PSBT, where
  /// the policy object is not available.
  static List<Uint8List>? getPublicKeysFromScript(Script script) {
    return _parseScript(script)?.publicKeys;
  }

  /// Threshold of a `multi_a` leaf, or `null` when [script] is not one.
  static int? getRequiredSignatureFromScript(Script script) {
    return _parseScript(script)?.requiredSignature;
  }

  static ({int requiredSignature, List<Uint8List> publicKeys})? _parseScript(
      Script script) {
    final List<dynamic> cmds = script.commands;
    // n keys, each with its own opcode, then the threshold and OP_NUMEQUAL.
    if (cmds.length < 4 || cmds.length.isOdd) {
      return null;
    }
    if (cmds.last != ScriptOperationCode.getHex('OP_NUMEQUAL')) {
      return null;
    }

    final List<Uint8List> publicKeys = [];
    for (int i = 0; i < cmds.length - 2; i += 2) {
      final dynamic publicKey = cmds[i];
      if (publicKey is! Uint8List || publicKey.length != 32) {
        return null;
      }
      final dynamic opCode = cmds[i + 1];
      // The first key opens the accumulator, the rest add to it.
      if (opCode !=
          ScriptOperationCode.getHex(
              i == 0 ? 'OP_CHECKSIG' : 'OP_CHECKSIGADD')) {
        return null;
      }
      publicKeys.add(publicKey);
    }

    final dynamic threshold = cmds[cmds.length - 2];
    if (threshold is! int) {
      return null;
    }
    // OP_1..OP_16 push 1..16.
    final int requiredSignature = threshold - 0x50;
    if (requiredSignature < 1 || requiredSignature > publicKeys.length) {
      return null;
    }

    return (requiredSignature: requiredSignature, publicKeys: publicKeys);
  }

  @override
  Script toScript(int addressIndex, {bool isChange = false}) {
    List<dynamic> cmds = [];

    for (int i = 0; i < _keyStoreList.length; i++) {
      cmds.add(_keyStoreList[i]
          .getPublicKeyBytes(addressIndex, isChange: isChange, isXOnly: true));
      // The first key opens the accumulator, the rest add to it.
      cmds.add(ScriptOperationCode.getHex(
          i == 0 ? 'OP_CHECKSIG' : 'OP_CHECKSIGADD'));
    }

    cmds.add(ScriptOperationCode.getHex('OP_$_requiredSignature'));
    cmds.add(ScriptOperationCode.getHex('OP_NUMEQUAL'));

    return Script(cmds);
  }

  @override
  String toMiniscript() {
    final String keys = _keyStoreList
        .map((keyStore) => Policy._getKeyOriginExpression(keyStore))
        .join(',');
    return 'multi_a($_requiredSignature,$keys)';
  }

  @override
  String toJson() {
    return jsonEncode({
      'type': 'multisignature',
      'requiredSignature': _requiredSignature,
      // Keep the same JSON convention as the rest of the library:
      // nested objects are stored as JSON strings.
      'keyStoreList':
          _keyStoreList.map((keyStore) => keyStore.toJson()).toList(),
      // Convenience for debugging / legacy parsing
      'miniscript': toMiniscript(),
    });
  }

  factory MultisignaturePolicy.fromJson(String jsonStr) {
    final Map<String, dynamic> map =
        Codec._decodeJsonObject(jsonStr, name: 'MultisignaturePolicy JSON');
    final int requiredSignature = Codec._readJsonField<int>(
        map, 'requiredSignature',
        name: 'MultisignaturePolicy JSON');
    final List<dynamic> keyStoreJsonList = Codec._readJsonField<List<dynamic>>(
        map, 'keyStoreList',
        name: 'MultisignaturePolicy JSON');

    final List<KeyStore> keyStoreList = [];
    for (dynamic keyStoreJson in keyStoreJsonList) {
      if (keyStoreJson is! String) {
        throw const FormatException(
            'MultisignaturePolicy JSON field "keyStoreList" must hold JSON strings.');
      }
      keyStoreList.add(KeyStore.fromJson(keyStoreJson));
    }

    return MultisignaturePolicy(keyStoreList, requiredSignature);
  }

  static Policy fromMiniscript(String miniscript) {
    final RegExpMatch? match =
        RegExp(r'^multi_a\((\d+),(.+)\)$').firstMatch(miniscript);
    if (match == null) {
      throw FormatException('Unsupported multisignature miniscript.');
    }

    final int requiredSignature = int.parse(match.group(1)!);
    // Key origin expressions contain no commas, so a plain split is safe.
    final List<KeyStore> keyStoreList = match
        .group(2)!
        .split(',')
        .map(Policy._parseKeyOriginExpression)
        .toList();

    return MultisignaturePolicy(keyStoreList, requiredSignature);
  }
}
