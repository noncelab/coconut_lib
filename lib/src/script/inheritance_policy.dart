part of '../../coconut_lib.dart';

/// Taproot script-path policy requiring a beneficiary signature after locktime.
///
/// {@category Scripts and Policies}
class InheritancePolicy extends Policy {
  static const int maxLocktime = 0x7fffffff;

  KeyStore beneficiaryKeyStore;
  final int locktime;

  InheritancePolicy(this.beneficiaryKeyStore, int locktime)
      : locktime = _validateLocktime(locktime),
        super();

  static int _validateLocktime(int locktime) {
    if (locktime < 0 || locktime > maxLocktime) {
      throw RangeError.range(locktime, 0, maxLocktime, 'locktime');
    }
    return locktime;
  }

  factory InheritancePolicy.fromDescriptorAndLocktime(
      String descriptor, int locktime) {
    Descriptor beneficiaryDescriptor = Descriptor.parse(descriptor);
    if (!beneficiaryDescriptor._addressType.isTaproot) {
      throw Exception('Only Taproot address type is supported.');
    } else if (beneficiaryDescriptor._keyOriginExpressionList.length > 1) {
      throw Exception('Only single signature address type is supported.');
    } else if (beneficiaryDescriptor.miniscriptList.isNotEmpty) {
      throw Exception('Taproot script is not supported.');
    } else {
      TaprootWallet beneficiaryWallet =
          TaprootWallet.fromDescriptor(descriptor);
      if (beneficiaryWallet.keyStoreList.length > 1) {
        throw Exception('Only single signature address type is supported.');
      }
      return InheritancePolicy(beneficiaryWallet.keyStoreList[0], locktime);
    }
  }

  @override
  List<KeyStore> get keyStoreList => List.unmodifiable([beneficiaryKeyStore]);

  @override
  bool bindKeyStore(KeyStore keyStore) {
    if (!beneficiaryKeyStore.hasSamePublicIdentity(keyStore)) {
      return false;
    }
    beneficiaryKeyStore = keyStore;
    return true;
  }

  @override
  Script toScript(int addressIndex, {bool isChange = false}) {
    List<dynamic> cmds = [];
    Uint8List beneficiaryPublicKey = beneficiaryKeyStore
        .getPublicKeyBytes(addressIndex, isChange: isChange, isXOnly: true);

    Uint8List locktimeBytes = Converter.intToLittleEndianBytes(locktime, 4);
    cmds.add(locktimeBytes);
    cmds.add(ScriptOperationCode.getHex('OP_CHECKLOCKTIMEVERIFY'));
    cmds.add(ScriptOperationCode.getHex('OP_DROP'));
    cmds.add(beneficiaryPublicKey);
    cmds.add(ScriptOperationCode.getHex('OP_CHECKSIG'));

    return Script(cmds);
  }

  /// The spelling written into descriptors and policy JSON.
  ///
  /// This is `and_v(v:pk(K),after(N))`, which is NOT what [toScript] builds —
  /// see [toStandardMiniscript] for the spelling that is. It is kept because
  /// wallets already in the field exchange descriptors in this form, and
  /// switching the output would break them. Both spellings are read back by
  /// [fromMiniscript], so the output can be moved to the standard one once
  /// those wallets are ready.
  @override
  String toMiniscript() {
    return 'and_v(v:pk(${_keyOriginExpression()}),after($locktime))';
  }

  /// The leaf as standard miniscript: what [toScript] actually builds.
  ///
  /// `and_v(v:after(N),pk(K))` compiles to `<N> CLTV DROP <K> CHECKSIG`, the
  /// script this policy commits to. The reverse spelling that [toMiniscript]
  /// emits compiles to `<K> CHECKSIGVERIFY <N> CLTV` — a different script, a
  /// different leaf hash, and so a different address for anyone deriving from
  /// the descriptor rather than from this library.
  String toStandardMiniscript() {
    return 'and_v(v:after($locktime),pk(${_keyOriginExpression()}))';
  }

  String _keyOriginExpression() {
    final KeyStore publicBeneficiaryKeyStore = KeyStore.fromExtendedPublicKey(
        beneficiaryKeyStore.extendedPublicKey.serialize(),
        beneficiaryKeyStore.masterFingerprint);
    return TaprootWallet.fromKeyStoreList([publicBeneficiaryKeyStore], [])
        .getKeyOriginExpression();
  }

  @override
  String toJson() {
    return jsonEncode({
      'type': 'inheritance',
      'locktime': locktime,
      // Keep the same JSON convention as the rest of the library:
      // nested objects are stored as JSON strings.
      'beneficiaryKeyStore': beneficiaryKeyStore.toJson(),
      // Convenience for debugging / legacy parsing
      'miniscript': toMiniscript(),
    });
  }

  factory InheritancePolicy.fromJson(String jsonStr) {
    final Map<String, dynamic> map =
        Codec._decodeJsonObject(jsonStr, name: 'InheritancePolicy JSON');
    final int locktime = Codec._readJsonField<int>(map, 'locktime',
        name: 'InheritancePolicy JSON');
    final String keyStoreJson = Codec._readJsonField<String>(
        map, 'beneficiaryKeyStore',
        name: 'InheritancePolicy JSON');
    final KeyStore beneficiaryKeyStore = KeyStore.fromJson(keyStoreJson);

    return InheritancePolicy(beneficiaryKeyStore, locktime);
  }

  static Policy fromMiniscript(String miniscript) {
    /// Standard spelling, matching [toScript] — see [toStandardMiniscript].
    final RegExp _miniscriptPattern =
        RegExp(r'^and_v\(v:after\((\d+)\),pk\((.+)\)\)$');

    /// The spelling [toMiniscript] emits, and what wallets in the field send.
    final RegExp _legacyMiniscriptPattern =
        RegExp(r'^and_v\(v:pk\((.+)\),after\((\d+)\)\)$');

    late final String pubkeyHex;
    late final int locktime;

    final RegExpMatch? match = _miniscriptPattern.firstMatch(miniscript);
    if (match != null) {
      locktime = int.parse(match.group(1)!);
      pubkeyHex = match.group(2)!;
    } else {
      final RegExpMatch? legacyMatch =
          _legacyMiniscriptPattern.firstMatch(miniscript);
      if (legacyMatch == null) {
        throw FormatException('Unsupported inheritance miniscript.');
      }
      pubkeyHex = legacyMatch.group(1)!;
      locktime = int.parse(legacyMatch.group(2)!);
    }
    TaprootWallet beneficiaryWallet =
        TaprootWallet.fromKeyOriginExpression(pubkeyHex);
    if (beneficiaryWallet.keyStoreList.length > 1) {
      throw Exception('Only single signature address type is supported.');
    }
    return InheritancePolicy(beneficiaryWallet.keyStoreList[0], locktime);
  }
}
