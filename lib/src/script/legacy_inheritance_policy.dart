part of '../../coconut_lib.dart';

/// [InheritancePolicy] whose leaf cleans the stack with `OP_DROP`.
///
/// Earlier versions built the inheritance leaf as
/// `<N> CLTV DROP <K> CHECKSIG`. Miniscript compiles `v:after(N)` to
/// `<N> CLTV VERIFY` (BIP-379), which is what [InheritancePolicy] builds now.
/// The two scripts behave alike for `N >= 1` but commit to different leaf
/// hashes, so a vault funded under the old leaf only derives its address, and
/// only spends, with this class.
///
/// No miniscript fragment compiles to `DROP`, so [toMiniscript] spells the
/// leaf with the non-standard `after_drop(N)`. Other tools reject it instead
/// of deriving a different address from it.
///
/// {@category Scripts and Policies}
class LegacyInheritancePolicy extends InheritancePolicy {
  LegacyInheritancePolicy(super.beneficiaryKeyStore, super.locktime);

  factory LegacyInheritancePolicy.fromDescriptorAndLocktime(
      String descriptor, int locktime) {
    final InheritancePolicy policy =
        InheritancePolicy.fromDescriptorAndLocktime(descriptor, locktime);
    return LegacyInheritancePolicy(policy.beneficiaryKeyStore, locktime);
  }

  /// `<N> CLTV DROP <K> CHECKSIG`
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

  /// `and_v(after_drop(N),pk(K))`, a spelling only this library reads.
  @override
  String toMiniscript() {
    return 'and_v(after_drop($locktime),pk(${_keyOriginExpression()}))';
  }

  @override
  String toJson() {
    return jsonEncode({
      'type': 'legacyInheritance',
      'locktime': locktime,
      'beneficiaryKeyStore': beneficiaryKeyStore.toJson(),
      'miniscript': toMiniscript(),
    });
  }

  factory LegacyInheritancePolicy.fromJson(String jsonStr) {
    final Map<String, dynamic> map =
        Codec._decodeJsonObject(jsonStr, name: 'LegacyInheritancePolicy JSON');
    final int locktime = Codec._readJsonField<int>(map, 'locktime',
        name: 'LegacyInheritancePolicy JSON');
    final String keyStoreJson = Codec._readJsonField<String>(
        map, 'beneficiaryKeyStore',
        name: 'LegacyInheritancePolicy JSON');

    return LegacyInheritancePolicy(KeyStore.fromJson(keyStoreJson), locktime);
  }

  static Policy fromMiniscript(String miniscript) {
    final RegExpMatch? match =
        RegExp(r'^and_v\(after_drop\((\d+)\),pk\((.+)\)\)$')
            .firstMatch(miniscript);
    if (match == null) {
      throw FormatException('Unsupported legacy inheritance miniscript.');
    }
    final TaprootWallet beneficiaryWallet =
        TaprootWallet.fromKeyOriginExpression(match.group(2)!);
    if (beneficiaryWallet.keyStoreList.length > 1) {
      throw Exception('Only single signature address type is supported.');
    }
    return LegacyInheritancePolicy(
        beneficiaryWallet.keyStoreList[0], int.parse(match.group(1)!));
  }
}
