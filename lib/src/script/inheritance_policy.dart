part of '../../coconut_lib.dart';

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
    } else if (beneficiaryDescriptor.miniscriptList.length > 0) {
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

  @override
  String toMiniscript() {
    final KeyStore publicBeneficiaryKeyStore = KeyStore.fromExtendedPublicKey(
        beneficiaryKeyStore.extendedPublicKey.serialize(),
        beneficiaryKeyStore.masterFingerprint);
    TaprootWallet beneficiaryWallet =
        TaprootWallet.fromKeyStoreList([publicBeneficiaryKeyStore], []);
    return 'and_v(v:pk(${beneficiaryWallet.getKeyOriginExpression()}),after($locktime))';
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
    final RegExpMatch? match = RegExp(r'^and_v\(v:pk\((.+)\),after\((\d+)\)\)$')
        .firstMatch(miniscript);
    if (match == null) {
      throw FormatException('Unsupported inheritance miniscript.');
    }
    String pubkeyHex = match.group(1)!;
    int locktime = int.parse(match.group(2)!);
    TaprootWallet beneficiaryWallet =
        TaprootWallet.fromKeyOriginExpression(pubkeyHex);
    if (beneficiaryWallet.keyStoreList.length > 1) {
      throw Exception('Only single signature address type is supported.');
    }
    return InheritancePolicy(beneficiaryWallet.keyStoreList[0], locktime);
  }
}
