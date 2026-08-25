part of '../../coconut_lib.dart';

/// Represents an address type of Bitcoin.
class AddressType {
  /// Address type for P2PKH(Legacy) address.
  static AddressType p2pkh = AddressType._(
      'p2pkh',
      44,
      '1',
      'pkh',
      0x0488b21e,
      0x043587cf,
      getP2pkhAddress,
      getWrongMultisigatureAddress,
      getWrongTaprootAddress);

  /// Address type for P2WPKH(Native Segwit) address.
  static AddressType p2wpkh = AddressType._(
      'p2wpkh',
      84,
      'bc1',
      'wpkh',
      0x04b24746,
      0x045f1cf6,
      getP2wpkhAddress,
      getWrongMultisigatureAddress,
      getWrongTaprootAddress);

  /// Address type for P2WSH-in-P2SH(Nested Segwit) address.
  static AddressType p2wpkhInP2sh = AddressType._(
      'p2wpkhInP2sh',
      49,
      '3',
      'sh-wpkh',
      0x049d7cb2,
      0x044a5262,
      getP2wpkhInP2shAddress,
      getWrongMultisigatureAddress,
      getWrongTaprootAddress);

  /// Address type for P2SH(Legacy Multisig) address.
  static AddressType p2sh = AddressType._('p2sh', 45, '3', 'sh', 0x0488b21e,
      0x043587cf, getWrongAddress, getP2shAddress, getWrongTaprootAddress);

  /// Address type for P2WSH(Segwit Multisig) address.
  static AddressType p2wsh = AddressType._(
      'p2wsh',
      48,
      'bc1',
      'wsh',
      0x02aa7ed3,
      0x02575483,
      getWrongAddress,
      getP2wshAddress,
      getWrongTaprootAddress);

  /// Address type for P2TR(Taproot) address.
  static AddressType p2tr = AddressType._(
      'p2tr',
      86,
      'bc1',
      'tr',
      0x0488b21e,
      0x043587cf,
      getWrongAddress,
      getWrongMultisigatureAddress,
      getP2trTaprootAddress);

  /// List of all address types.
  static List<AddressType> get values =>
      [p2pkh, p2wpkh, p2wpkhInP2sh, p2sh, p2wsh, p2tr];

  /// The name of the address type. (legacy, segwit, nestedSegwit, p2sh, p2wsh)
  final String name;

  /// The purpose index of the address type. (BIP-0044)
  final int purposeIndex;

  /// The prefix of the address.
  final String prefix;

  /// The script type of the address. (P2PKH, P2WPKH, P2WPKH-in-P2SH, P2SH, P2WSH)
  final String scriptType;

  /// Check if the address type is segwit.
  bool get isSegwit => scriptType.startsWith('w') || scriptType.contains('tr');

  /// Check if the address type is for multisig.
  bool get isMultisignature =>
      name == 'p2sh' || name == 'p2wsh' || name == 'p2trScriptPathSpending';

  /// Check if the address type is for single signature.
  bool get isSingleSignature =>
      name == 'p2pkh' || name == 'p2wpkh' || name == 'p2wpkhInP2sh';

  // Check if the address type is for taproot.
  bool get isTaproot => name.startsWith('p2tr');

  /// @nodoc
  final int versionForMainnet;

  /// @nodoc
  final int versionForTestnet;

  /// Get the address from the public key. (not for multisig)
  final String Function(String) getAddress;

  /// Get the multisignature address from the public keys and required signatures. (for multisig)
  final String Function(List<String>, int) getMultisignatureAddress;

  /// Get the taproot address from the internal key and merkle root.
  final String Function(String) getTaprootAddress;

  AddressType._(
      this.name,
      this.purposeIndex,
      this.prefix,
      this.scriptType,
      this.versionForMainnet,
      this.versionForTestnet,
      this.getAddress,
      this.getMultisignatureAddress,
      this.getTaprootAddress);

  /// Get the address type from the script type.(P2PKH, P2WPKH, P2WSH-in-P2SH, P2SH, P2WSH)
  static AddressType getAddressTypeFromScriptType(String scriptType) {
    for (AddressType type in values) {
      if (type.scriptType.toUpperCase() == scriptType.toUpperCase()) {
        return type;
      }
    }
    throw Exception("Not supported address type.");
  }

  static AddressType getAddressTypeFromName(String name) {
    for (AddressType type in values) {
      if (type.name.toUpperCase() == name.toUpperCase()) {
        return type;
      }
    }
    throw Exception("Not supported address type.");
  }

  /// @nodoc
  static bool isTestnetVersion(int version) {
    for (AddressType type in values) {
      if (type.versionForTestnet == version) {
        return true;
      } else if (type.versionForMainnet == version) {
        return false;
      }
    }

    throw Exception('AddressType : Invalid version.');
  }

  /// @nodoc
  static AddressType getAddressTypeByVersion(int version) {
    for (AddressType type in values) {
      if (type.versionForTestnet == version ||
          type.versionForMainnet == version) {
        return type;
      }
    }

    throw Exception('AddressType : Invalid version.');
  }

  static String _getSegwitHrp() {
    NetworkType network = NetworkType.currentNetworkType;
    if (network == NetworkType.mainnet) {
      return 'bc';
    } else if (network == NetworkType.testnet) {
      return 'tb';
    } else {
      return 'bcrt';
    }
  }

  /// @nodoc
  static String getP2wpkhAddress(String publicKey) {
    String hrp = _getSegwitHrp();
    final program = Hash.sha160fromHex(publicKey);
    var data = Converter.convertBits(program, 8, 5, pad: true);
    return bech32.encode(Bech32(hrp, [0x00] + data));
  }

  /// @nodoc
  static String getP2pkhAddress(String publicKey) {
    bool isTestnet = NetworkType.currentNetworkType.isTestnet;
    final ripemd160HashOfSha256 = Hash.sha160fromHex(publicKey);
    final extendedRipemd160Hash = Uint8List(ripemd160HashOfSha256.length + 1);
    if (isTestnet) {
      extendedRipemd160Hash[0] = 0x6f;
    } else {
      extendedRipemd160Hash[0] = 0x00;
    }
    extendedRipemd160Hash.setRange(
        1, extendedRipemd160Hash.length, ripemd160HashOfSha256);
    final sha256HashOfExtendedRipemd160 =
        Hash.sha256fromByte(extendedRipemd160Hash);

    final sha256HashOfSha256Hash =
        Hash.sha256fromByte(sha256HashOfExtendedRipemd160);

    final checksum = sha256HashOfSha256Hash.sublist(0, 4);

    final addressBytes =
        Uint8List(extendedRipemd160Hash.length + checksum.length);
    addressBytes.setRange(
        0, extendedRipemd160Hash.length, extendedRipemd160Hash);
    addressBytes.setRange(
        extendedRipemd160Hash.length, addressBytes.length, checksum);
    return Codec.encodeBase58(addressBytes);
  }

  /// @nodoc
  static String getP2wpkhInP2shAddress(String publicKey) {
    bool isTestnet = NetworkType.currentNetworkType.isTestnet;
    var push_20 = Uint8List.fromList([0x00, 0x14]);
    var scriptSig =
        Uint8List.fromList([...push_20, ...Hash.sha160fromHex(publicKey)]);
    var prefix = 0;
    if (isTestnet) {
      prefix = 0xc4;
    } else {
      prefix = 0x05;
    }

    var address =
        (Uint8List.fromList([prefix, ...Hash.sha160fromByte(scriptSig)]));

    return Codec.encodeBase58Checksum(address);
  }

  /// @nodoc
  static String getP2shAddress(
      List<String> publicKeys, int requiredSignatures) {
    _validateMultisignaturePublicKeys(publicKeys, requiredSignatures);
    bool isTestnet = NetworkType.currentNetworkType.isTestnet;
    publicKeys = List<String>.of(publicKeys)..sort();
    List<Uint8List> pubKeysBytes =
        publicKeys.map((key) => Codec.decodeHex(key)).toList();
    var redeemScript = <int>[];
    redeemScript.add(0x50 + requiredSignatures); // <m>
    for (var pubKey in pubKeysBytes) {
      redeemScript.add(pubKey.length); // Pubkey length
      redeemScript.addAll(pubKey); // Pubkey bytes
    }
    redeemScript.add(0x50 + publicKeys.length); // <n>
    redeemScript.add(0xAE); // OP_CHECKMULTISIG
    Uint8List redeemScriptHash =
        Hash.sha160fromByte(Uint8List.fromList(redeemScript));
    var networkPrefix = isTestnet ? 0xC4 : 0x05;
    var addressBytes = [networkPrefix, ...redeemScriptHash];
    var base58Address =
        Codec.encodeBase58Checksum(Uint8List.fromList(addressBytes));

    return base58Address;
  }

  /// @nodoc
  static String getP2wshAddress(
      List<String> publicKeys, int requiredSignatures) {
    _validateMultisignaturePublicKeys(publicKeys, requiredSignatures);
    publicKeys = List<String>.of(publicKeys)..sort();

    List<Uint8List> pubKeys =
        publicKeys.map((hex) => Codec.decodeHex(hex)).toList();

    var redeemScript = <int>[];
    redeemScript.add(0x50 + requiredSignatures);

    for (var pubKey in pubKeys) {
      redeemScript.add(pubKey.length);
      redeemScript.addAll(pubKey);
    }

    redeemScript.add(0x50 + pubKeys.length);

    redeemScript.add(0xae);

    Uint8List redeemScriptHash =
        Hash.sha256fromByte(Uint8List.fromList(redeemScript));

    var version = 0x00; // 0x00 for P2WSH

    var program = Converter.convertBits(redeemScriptHash, 8, 5, pad: true);
    var hrp = _getSegwitHrp();
    var address = bech32.encode(Bech32(hrp, [version] + program));

    return address;
  }

  static String getP2trScriptPathSpendingAddress(
      List<String> publicKeys, int requiredSignature) {
    _validateMultisignaturePublicKeys(publicKeys, requiredSignature);
    if (requiredSignature > 3) {
      throw Exception("requiredSignature cannot be greater than 3");
    }
    if (requiredSignature > publicKeys.length) {
      throw Exception(
          "requiredSignature cannot be greater than the number of pubkeys");
    }
    publicKeys = List<String>.of(publicKeys)..sort();
    for (var publicKey in publicKeys) {
      if (Codec.decodeHex(publicKey).length != 32) {
        throw Exception("Public Key must be a 32-byte x-only public key.");
      }
    }
    List<Uint8List> pubList =
        publicKeys.map((hex) => Codec.decodeHex(hex)).toList();

    String concatenedPubkeys = pubList.map((e) => Codec.encodeHex(e)).join('');

    String internalKey = Hash.sha256fromHex(concatenedPubkeys);

    List<int> tapscript = [];
    if (publicKeys.length == requiredSignature) {
      for (var i = 0; i < pubList.length - 1; i++) {
        tapscript.add(pubList[i].length);
        tapscript.addAll(pubList[i]);
        tapscript.add(0xad); // OP_CHECKSIGVERIFY
      }
      tapscript.add(pubList.last.length);
      tapscript.addAll(pubList.last);
      tapscript.add(0xac); // OP_CHECKSIG
    } else {
      for (var i = 0; i < pubList.length; i++) {
        tapscript.addAll(pubList[i]);
        tapscript.add(0xac); // OP_CHECKSIGADD
      }
      tapscript.add(requiredSignature);
      tapscript.add(0x87); // OP_NUMEQUAL
    }

    // Uint8List merkleRoot = _getTapleafHash(0xc0, Codec.encodeHex(tapscript));

    return getTaprootAddressFromTweakedPublicKey(internalKey);
  }

  static void _validateMultisignaturePublicKeys(
      List<String> publicKeys, int requiredSignatures) {
    final distinctPublicKeys =
        publicKeys.map((key) => key.toLowerCase()).toSet();
    if (distinctPublicKeys.length != publicKeys.length) {
      throw Exception('Duplicate public key.');
    }
    if (requiredSignatures < 1 ||
        requiredSignatures > distinctPublicKeys.length) {
      throw Exception(
          'Required signatures must be between 1 and the distinct signer count.');
    }
  }

  static String getTaprootAddressFromTweakedPublicKey(String tweakedPubKey) {
    Uint8List tweakedPubKeyBytes = Codec.decodeHex(tweakedPubKey);

    var data5Bits = Converter.convertBits(
        Uint8List.fromList(tweakedPubKeyBytes), 8, 5,
        pad: true);

    bech32m.Bech32mCodec codec = bech32m.Bech32mCodec();
    return codec.encode(bech32m.Bech32m(_getSegwitHrp(), [0x01] + data5Bits));
  }

  // static String getP2trTaprootAddress(String internalKey,
  //     {String? merkleRoot}) {
  //   if (internalKey.length != 64) {
  //     throw Exception("Invalid internal key length");
  //   }
  //   Uint8List internalKeyBytes = Codec.decodeHex(internalKey);
  //   Uint8List merkleRootBytes =
  //       merkleRoot != null ? Codec.decodeHex(merkleRoot) : Uint8List(0);

  //   Uint8List keyToTweak = internalKeyBytes;
  //   Uint8List hashTapTweak =
  //       Hash.hashTapTweak('TapTweak', keyToTweak, merkleRootBytes);

  //   Uint8List tweakedPubKey =
  //       Ecc.pointAddScalar(keyToTweak, hashTapTweak, true)!;

  //   if (tweakedPubKey[0] == 0x03) {
  //     tweakedPubKey = Ecc.pointNegate(tweakedPubKey)!;
  //   }

  //   Uint8List outputKey = tweakedPubKey.sublist(1);

  //   var data5Bits = Converter.convertBits(
  //       Uint8List.fromList(tweakedPubKey.sublist(1)), 8, 5,
  //       pad: true);

  //   bech32m.Bech32mCodec codec = bech32m.Bech32mCodec();
  //   return codec.encode(bech32m.Bech32m(_getSegwitHrp(), [0x01] + data5Bits));
  // }
  static String getP2trTaprootAddress(String outputKey) {
    Uint8List outputKeyBytes = Codec.decodeHex(outputKey);
    var data5Bits = Converter.convertBits(
        Uint8List.fromList(outputKeyBytes), 8, 5,
        pad: true);

    bech32m.Bech32mCodec codec = bech32m.Bech32mCodec();
    return codec.encode(bech32m.Bech32m(_getSegwitHrp(), [0x01] + data5Bits));
  }

  /// @nodoc
  static String getWrongAddress(String publicKey) {
    throw Exception('Use getMultisigAddress for multisig address type.');
  }

  /// @nodoc
  static String getWrongMultisigatureAddress(
      List<String> publicKey, int requiredSignature) {
    throw Exception('Use getAddress for non multisig address type.');
  }

  static String getWrongTaprootAddress(String internalKey,
      {String? merkleRoot}) {
    throw Exception('Use getTaprootAddress for taproot address type.');
  }

  /// @nodoc
  @override
  String toString() => scriptType;

  /// @nodoc
  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is AddressType) {
      return name == other.name;
    }
    return false;
  }
}
