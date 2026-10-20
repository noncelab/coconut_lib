part of '../../coconut_lib.dart';

/// Taproot script-path policy requiring a beneficiary signature after locktime.
///
/// {@category Scripts and Policies}
class InheritancePolicy extends Policy {
  /// Largest locktime `after(N)` allows, BIP-379: `N < 2^31`.
  static const int maxLocktime = 0x7fffffff;

  /// Smallest locktime `after(N)` allows, BIP-379: `1 <= N`.
  ///
  /// `<0> CLTV VERIFY` fails, since VERIFY pops the empty push as false, so a
  /// leaf with locktime 0 could never be spent.
  static const int minLocktime = 1;

  KeyStore beneficiaryKeyStore;
  final int locktime;

  InheritancePolicy(KeyStore beneficiaryKeyStore, int locktime)
      : this._(beneficiaryKeyStore, locktime, minLocktime);

  /// [minimum] is 0 for [LegacyInheritancePolicy], whose `CLTV DROP` leaf is
  /// valid at 0 and may already hold funds with that locktime.
  InheritancePolicy._(this.beneficiaryKeyStore, int locktime, int minimum)
      : locktime = locktime < minimum || locktime > maxLocktime
            ? throw RangeError.range(locktime, minimum, maxLocktime, 'locktime')
            : locktime,
        super();

  /// The locktime as the push a miniscript compiler emits for `<N>`.
  ///
  /// Script numbers are minimal (BIP-62 rule 4): `OP_1`..`OP_16` for 1..16,
  /// otherwise the fewest little-endian bytes, with a zero byte added when the
  /// top bit would read as a sign. Always pushing four bytes gives a different
  /// leaf, and so a different address, for any `N < 2^23` such as a block
  /// height.
  static dynamic _locktimePush(int locktime) {
    if (locktime >= 1 && locktime <= 16) {
      return ScriptOperationCode.getHex('OP_$locktime');
    }
    final List<int> bytes = [];
    for (int value = locktime; value > 0; value >>= 8) {
      bytes.add(value & 0xff);
    }
    if (bytes.last & 0x80 != 0) {
      bytes.add(0);
    }
    return Uint8List.fromList(bytes);
  }

  factory InheritancePolicy.fromDescriptorAndLocktime(
      String descriptor, int locktime) {
    return InheritancePolicy(_beneficiaryFromDescriptor(descriptor), locktime);
  }

  /// The single Taproot key a beneficiary descriptor holds.
  static KeyStore _beneficiaryFromDescriptor(String descriptor) {
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
      return beneficiaryWallet.keyStoreList[0];
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

  /// `<N> CLTV VERIFY <K> CHECKSIG`, what miniscript `and_v(v:after(N),pk(K))`
  /// compiles to (BIP-379), with `<N>` pushed as a minimal script number.
  @override
  Script toScript(int addressIndex, {bool isChange = false}) {
    List<dynamic> cmds = [];
    Uint8List beneficiaryPublicKey = beneficiaryKeyStore
        .getPublicKeyBytes(addressIndex, isChange: isChange, isXOnly: true);

    cmds.add(_locktimePush(locktime));
    cmds.add(ScriptOperationCode.getHex('OP_CHECKLOCKTIMEVERIFY'));
    cmds.add(ScriptOperationCode.getHex('OP_VERIFY'));
    cmds.add(beneficiaryPublicKey);
    cmds.add(ScriptOperationCode.getHex('OP_CHECKSIG'));

    return Script(cmds);
  }

  /// The same beneficiary and locktime as a [LegacyInheritancePolicy].
  ///
  /// For vaults funded before the leaf switched from `CLTV DROP` to
  /// `CLTV VERIFY`: only the legacy leaf derives their address.
  LegacyInheritancePolicy toLegacy() =>
      LegacyInheritancePolicy(beneficiaryKeyStore, locktime);

  /// The leaf as standard miniscript, matching what [toScript] builds.
  ///
  /// `and_v(v:after(N),pk(K))` compiles to `<N> CLTV VERIFY <K> CHECKSIG`, the
  /// script [toScript] builds. The reverse spelling,
  /// `and_v(v:pk(K),after(N))`, compiles to `<K> CHECKSIGVERIFY <N> CLTV` — a
  /// different script, a different leaf hash, and so a different address for
  /// anyone deriving from the descriptor. Earlier versions emitted it, so
  /// [fromMiniscript] still reads it.
  @override
  String toMiniscript() {
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
      // Absent in JSON stored before the leaf became CLTV VERIFY; such JSON
      // describes a CLTV DROP leaf, see [Policy.fromJson].
      'scriptForm': 'verify',
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
    final RegExp miniscriptPattern =
        RegExp(r'^and_v\(v:after\((\d+)\),pk\((.+)\)\)$');

    final RegExp legacyMiniscriptPattern =
        RegExp(r'^and_v\(v:pk\((.+)\),after\((\d+)\)\)$');

    late final String pubkeyHex;
    late final int locktime;

    final RegExpMatch? match = miniscriptPattern.firstMatch(miniscript);
    if (match != null) {
      locktime = int.parse(match.group(1)!);
      pubkeyHex = match.group(2)!;
    } else {
      final RegExpMatch? legacyMatch =
          legacyMiniscriptPattern.firstMatch(miniscript);
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
