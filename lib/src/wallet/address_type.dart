part of '../../coconut_lib.dart';

/// Represents an address type of Bitcoin.
class AddressType {
  /// The name of the address type. (legacy, segwit, nestedSegwit, p2sh, p2wsh)
  final String name;

  /// The purpose index of the address type. (BIP-0044)
  final int purposeIndex;

  /// The prefix of the address.
  final String prefix;

  /// The script type of the address. (P2PKH, P2WPKH, P2WSH-in-P2SH, P2SH, P2WSH)
  final String scriptType;

  /// Check if the address type is segwit.
  final bool isSegwit;

  /// Check if the address type is for multisig.
  final bool isMultisig;

  /// @nodoc
  final int versionForMainnet;

  /// @nodoc
  final int versionForTestnet;

  /// Get the address from the public key. (not for multisig)
  final String Function(String) getAddress;

  /// Get the multisignature address from the public keys and required signatures. (for multisig)
  final String Function(List<String>, int) getMultisignatureAddress;

  AddressType._(
      this.name,
      this.purposeIndex,
      this.prefix,
      this.scriptType,
      this.isSegwit,
      this.isMultisig,
      this.versionForMainnet,
      this.versionForTestnet,
      this.getAddress,
      this.getMultisignatureAddress);

  /// Address type for P2PKH(Legacy) address.
  static AddressType p2pkh = AddressType._(
      'legacy',
      44,
      '1',
      'P2PKH',
      false,
      false,
      0x0488b21e,
      0x043587cf,
      getP2pkhAddress,
      getWrongMultisigatureAddress);

  /// Address type for P2WPKH(Native Segwit) address.
  static AddressType p2wpkh = AddressType._(
      'nativeSegwit',
      84,
      'bc1',
      'P2WPKH',
      true,
      false,
      0x04b24746,
      0x045f1cf6,
      getP2wpkhAddress,
      getWrongMultisigatureAddress);

  /// Address type for P2WSH-in-P2SH(Nested Segwit) address.
  static AddressType p2wpkhInP2sh = AddressType._(
      'nestedSegwit',
      49,
      '3',
      'P2WSH-in-P2SH',
      true,
      false,
      0x049d7cb2,
      0x044a5262,
      getP2wpkhInP2shAddress,
      getWrongMultisigatureAddress);

  /// Address type for P2SH(Legacy Multisig) address.
  static AddressType p2sh = AddressType._('p2sh', 45, '3', 'P2SH', false, true,
      0x0488b21e, 0x043587cf, getWrongAddress, getP2shAddress);

  /// Address type for P2WSH(Segwit Multisig) address.
  static AddressType p2wsh = AddressType._('p2wsh', 48, 'bc1', 'P2WSH', true,
      true, 0x02aa7ed3, 0x02575483, getWrongAddress, getP2wshAddress);

  /// List of all address types.
  static List<AddressType> get values =>
      [p2pkh, p2wpkh, p2wpkhInP2sh, p2sh, p2wsh];

  /// Get the address type from the script type.(P2PKH, P2WPKH, P2WSH-in-P2SH, P2SH, P2WSH)
  static AddressType getAddressTypeFromScriptType(String addressType) {
    for (AddressType type in values) {
      if (type.scriptType == addressType.toUpperCase()) {
        return type;
      }
    }
    throw Exception(
        "AddressType : only 'legacy' and 'nativeSegwit' supported.");
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
    BitcoinNetwork network = BitcoinNetwork.currentNetwork;
    if (network == BitcoinNetwork.mainnet) {
      return 'bc';
    } else if (network == BitcoinNetwork.testnet) {
      return 'tb';
    } else if (network == BitcoinNetwork.regtest) {
      return 'bcrt';
    }
    throw Exception('Invalid network');
  }

  /// @nodoc
  static String getP2wpkhAddress(String publicKey) {
    String hrp = _getSegwitHrp();

    //int version;
    final program = Hash.sha160fromHex(publicKey);

    var data = Converter.convertBits(program, 8, 5, pad: true);

    return bech32.encode(Bech32(hrp, [0x00] + data));
  }

  /// @nodoc
  static String getP2pkhAddress(String publicKey) {
    bool isTestnet = BitcoinNetwork.currentNetwork.isTestnet;
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
    return Base58.encode(addressBytes);
  }

  /// @nodoc
  static String getP2wpkhInP2shAddress(String publicKey) {
    bool isTestnet = BitcoinNetwork.currentNetwork.isTestnet;
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

    return Base58.encodeChecksum(address);
  }

  /// @nodoc
  static String getP2shAddress(
      List<String> publicKeys, int requiredSignatures) {
    bool isTestnet = BitcoinNetwork.currentNetwork.isTestnet;
    publicKeys.sort();
    List<Uint8List> pubKeysBytes =
        publicKeys.map((key) => Converter.hexToBytes(key)).toList();
    var redeemScript = <int>[];
    redeemScript.add(0x50 + requiredSignatures); // <m>
    for (var pubKey in pubKeysBytes) {
      redeemScript.add(pubKey.length); // Pubkey length
      redeemScript.addAll(pubKey); // Pubkey bytes
    }
    redeemScript.add(0x50 + publicKeys.length); // <n>
    redeemScript.add(0xAE); // OP_CHECKMULTISIG
    // print("Redeem:" + Converter.bytesToHex(redeemScript));
    Uint8List redeemScriptHash =
        Hash.sha160fromByte(Uint8List.fromList(redeemScript));
    var networkPrefix = isTestnet ? 0xC4 : 0x05;
    var addressBytes = [networkPrefix, ...redeemScriptHash];
    // print(Converter.bytesToHex(addressBytes));
    var base58Address = Base58.encodeChecksum(Uint8List.fromList(addressBytes));

    return base58Address;
  }

  /// @nodoc
  static String getP2wshAddress(
      List<String> publicKeys, int requiredSignatures) {
    publicKeys.sort();
    List<Uint8List> pubKeys =
        publicKeys.map((hex) => Converter.hexToBytes(hex)).toList();

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

  /// @nodoc
  static String getWrongAddress(String publicKey) {
    throw Exception('Use getMultisigAddress for multisig address type.');
  }

  /// @nodoc
  static String getWrongMultisigatureAddress(
      List<String> publicKey, int requiredSignature) {
    throw Exception('Use getAddress for non multisig address type.');
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
