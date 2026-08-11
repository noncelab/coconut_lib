part of '../../coconut_lib.dart';

/// Represents a descriptor of Bitcoin. (BIP-0380)
class Descriptor {
  String _scriptType;
  List<String> _keyOriginExpressionList = [];
  List<String> _miniscriptList = [];
  late int _requiredSignatures;
  AddressType _addressType;

  /// @nodoc
  Descriptor(this._scriptType, this._keyOriginExpressionList, this._addressType,
      {List<String>? miniscriptList, int? requiredSignatures}) {
    if (requiredSignatures == null) {
      if (_addressType.isSingleSignature) {
        _requiredSignatures = 1;
      } else if (_addressType == AddressType.p2tr) {
        _requiredSignatures = _keyOriginExpressionList.length;
      } else {
        throw Exception('Required signatures not specified.');
      }
    } else {
      _requiredSignatures = requiredSignatures;
    }
    if (miniscriptList != null) {
      _miniscriptList = miniscriptList;
    }
    if (_addressType.isMultisignature) {
      final List<KeyStore> keyStores = <KeyStore>[];
      for (int i = 0; i < _keyOriginExpressionList.length; i++) {
        final ExtendedPublicKey extendedPublicKey =
            ExtendedPublicKey.parse(getPublicKey(i), validateNetwork: false);
        keyStores.add(KeyStore(
          getFingerprint(i),
          HDWallet.fromPublicKey(
              extendedPublicKey.publicKey, extendedPublicKey.chainCode),
          extendedPublicKey,
        ));
      }
      MultisignatureWalletBase._validateSignerSet(
          _requiredSignatures, keyStores);
    }
  }

  /// Script type of the descriptor.
  String get scriptType => _scriptType;

  int get totalSigner => _keyOriginExpressionList.length;

  get miniscriptList => _miniscriptList;

  /// Create a descriptor for a single signature.
  factory Descriptor.forSingleSignature(
      AddressType addressType, KeyStore keyStore, String derivationPath) {
    String scriptType = addressType.scriptType;
    return Descriptor(scriptType,
        [getKeyOriginExpression(keyStore, derivationPath)], addressType);
  }

  /// Create a descriptor for multisignature.
  factory Descriptor.forMultisignature(
      AddressType addressType,
      List<KeyStore> keyStoreList,
      String derivationPath,
      int requiredSignatures) {
    //'wsh(sortedmulti(2,[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*,[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*,[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*))#x9cc762c';
    String scriptType = addressType.scriptType;
    List<String> keyOriginExpressionList = [];
    for (int i = 0; i < keyStoreList.length; i++) {
      keyOriginExpressionList
          .add(getKeyOriginExpression(keyStoreList[i], derivationPath));
    }
    return Descriptor(scriptType, keyOriginExpressionList, addressType,
        requiredSignatures: requiredSignatures);
  }

  /// Get the key origin expression.
  static String getKeyOriginExpression(
      KeyStore keyStore, String derivationPath) {
    return "[${keyStore.masterFingerprint}/${derivationPath.replaceAll("m/", "")}]${keyStore.extendedPublicKey.serialize()}/<0;1>/*";
  }

  /// Create a descriptor for taproot.
  factory Descriptor.forTaproot(
      AddressType addressType,
      List<KeyStore> keyStoreList,
      List<Policy> policyList,
      String derivationPath) {
    //tr(internal_key, script_tree)
    //internal_key: xpub/0/* or musig(xpub1/*,xpub2/*)
    //script_tree: {and_v(v:pk(beneficiary),older(52560))}, {and_v(v:pk(heir),after(900000))}
    //ex: tr(musig([aaaa/86h/0h/0h]xpub1/0/*,[bbbb/86h/0h/0h]xpub2/0/*),{and_v(v:pk([cccc/86h/0h/0h]xpub3/0/*),older(52560))})
    List<String> keyOriginList = [];
    for (KeyStore keyStore in keyStoreList) {
      keyOriginList.add(getKeyOriginExpression(keyStore, derivationPath));
    }
    List<String> miniscriptList = [];
    for (Policy policy in policyList) {
      miniscriptList.add(policy.toMiniscript());
    }

    late Descriptor descriptor;

    descriptor = Descriptor(
        addressType.scriptType,
        keyStoreList
            .map((e) => getKeyOriginExpression(e, derivationPath))
            .toList(),
        addressType,
        miniscriptList: policyList.map((e) => e.toMiniscript()).toList());

    return descriptor;
  }

  /// Parse the descriptor.
  factory Descriptor.parse(String descriptor, {bool ignoreChecksum = false}) {
    if (ignoreChecksum == false && !Checksum.isValidChecksum(descriptor)) {
      throw const FormatException('Invalid descriptor checksum or format.');
    }
    AddressType addressType =
        Descriptor.getAddressTypeFromDescriptor(descriptor);
    var withoutChecksum = descriptor.split('#')[0];
    RegExpMatch scriptTypeMatch =
        RegExp(r'(\w+)\((.+)\)').firstMatch(withoutChecksum)!;

    String scriptType = scriptTypeMatch.group(1)!;
    String scriptContent = scriptTypeMatch.group(2)!;
    List<String> pubKeyContent = [];

    int require = 1;
    if (addressType.isSingleSignature) {
      pubKeyContent.add(scriptContent);
    } else if (addressType == AddressType.p2wsh) {
      RegExpMatch isMultisigMatch =
          RegExp(r'(\w+)\((.+)\)').firstMatch(scriptContent)!;
      if (isMultisigMatch.group(1) == 'multi') {
        throw Exception('Unsorted multisig descriptor is not supported.');
      } else if (isMultisigMatch.group(1) == 'sortedmulti') {
        String multisigContent = isMultisigMatch.group(2)!;
        require = int.parse(multisigContent.split(',')[0]);
        pubKeyContent = multisigContent.split(',').sublist(1);
      } else {
        throw const FormatException('No multisig descriptor found.');
      }
    } else if (addressType == AddressType.p2tr) {
      // Parse tr(internal_key, {miniscript1}, {miniscript2}, ...)
      // or tr(musig(key1, key2, ...), {miniscript1}, {miniscript2}, ...)
      String inner = scriptContent;
      int parenDepth = 0;
      int braceDepth = 0;
      List<String> topLevelParts = [];
      StringBuffer current = StringBuffer();

      for (int i = 0; i < inner.length; i++) {
        String char = inner[i];

        if (char == '(') {
          parenDepth++;
        } else if (char == ')') {
          parenDepth--;
        } else if (char == '{') {
          braceDepth++;
        } else if (char == '}') {
          braceDepth--;
        }

        if (char == ',' && parenDepth == 0 && braceDepth == 0) {
          topLevelParts.add(current.toString().trim());
          current.clear();
        } else {
          current.write(char);
        }
      }
      if (current.isNotEmpty) {
        topLevelParts.add(current.toString().trim());
      }

      if (topLevelParts.isEmpty) {
        throw const FormatException('Invalid Taproot descriptor format.');
      }

      // First part is internal key
      String internalKeyPart = topLevelParts[0];
      List<String> miniscriptList = [];

      // Parse internal key (single key or musig)
      if (internalKeyPart.startsWith('musig(')) {
        // Extract keys from musig(sorted(key1, key2, ...))
        RegExpMatch? musigMatch =
            RegExp(r'musig\(sorted\((.+)\)\)').firstMatch(internalKeyPart);
        if (musigMatch == null) {
          throw Exception('Only sorted musig is supported.');
        }
        pubKeyContent =
            musigMatch.group(1)!.split(',').map((e) => e.trim()).toList();
        require = pubKeyContent.length;
      } else {
        // Single key origin expression
        pubKeyContent = [internalKeyPart];
        require = 1;
      }

      // Parse miniscript list from remaining parts
      for (int i = 1; i < topLevelParts.length; i++) {
        String miniscriptPart = topLevelParts[i];
        if (miniscriptPart == "{}") {
          continue;
        }
        // Remove surrounding braces { }
        if (miniscriptPart.startsWith('{') && miniscriptPart.endsWith('}')) {
          miniscriptList
              .add(miniscriptPart.substring(1, miniscriptPart.length - 1));
        } else {
          throw FormatException('Invalid miniscript format: $miniscriptPart');
        }
      }

      return Descriptor(scriptType, pubKeyContent, addressType,
          miniscriptList: miniscriptList, requiredSignatures: require);
    } else {
      throw Exception('Unsupported script type.');
    }

    return Descriptor(scriptType, pubKeyContent, addressType,
        requiredSignatures: require);
  }

  /// Get the derivation path.
  String getDerivationPath(int index) {
    String pub = _keyOriginExpressionList[index];
    RegExpMatch match = RegExp(r'\[(.+)\](.+)').firstMatch(pub)!;
    List<String> list = match.group(1)!.split('/').sublist(1);
    String derivationPath = 'm/${list.join('/')}';

    return derivationPath.replaceAll('h', "'");
  }

  /// Get the fingerprint.
  String getFingerprint(int index) {
    String pub = _keyOriginExpressionList[index];
    RegExpMatch match = RegExp(r'\[(.+)\](.+)').firstMatch(pub)!;
    String? fingerprint = match.group(1)!.split('/')[0];
    return fingerprint;
  }

  /// Get the public key.
  String getPublicKey(int index) {
    String pub = _keyOriginExpressionList[index];
    RegExpMatch match = RegExp(r'\[(.+)\](.+)').firstMatch(pub)!;
    String? pubkey = match.group(2)!.split('/')[0];

    return pubkey;
  }

  /// Serialize the descriptor.
  String serialize() {
    String body = '';

    if (_addressType.isTaproot) {
      String keyOriginExpression;
      if (_keyOriginExpressionList.length == 1) {
        keyOriginExpression = _keyOriginExpressionList[0];
      } else {
        keyOriginExpression =
            "musig(sorted(${_keyOriginExpressionList.join(',')}))";
      }
      if (_miniscriptList.isEmpty) {
        body = "tr($keyOriginExpression)";
      } else {
        body = "tr($keyOriginExpression,{${_miniscriptList.join('},{')}})";
      }
    } else if (_addressType.isSingleSignature) {
      body = "$_scriptType(${_keyOriginExpressionList[0]})";
    } else if (_addressType == AddressType.p2wsh) {
      body = "$_scriptType(sortedmulti($_requiredSignatures";
      for (String pub in _keyOriginExpressionList) {
        body += ",$pub";
      }
      body += "))";
    } else {
      throw Exception('Unsupported script type.');
    }

    return '$body#${Checksum.getChecksum(body)}';
  }

  static AddressType getAddressTypeFromDescriptor(String descriptor) {
    if (descriptor.startsWith('wpkh')) {
      return AddressType.p2wpkh;
    } else if (descriptor.startsWith('wsh')) {
      return AddressType.p2wsh;
    } else if (descriptor.startsWith('tr')) {
      return AddressType.p2tr;
      // if (!descriptor.contains('musig(') && !descriptor.contains('pk(')) {
      //   return AddressType.p2trKeyPathSpending;
      // } else {
      //   String inner = descriptor.substring(3, descriptor.length - 1);
      //   int parenDepth = 0;
      //   int braceDepth = 0;
      //   List<String> topLevelParts = [];
      //   StringBuffer current = StringBuffer();
      //   for (int i = 0; i < inner.length; i++) {
      //     String char = inner[i];

      //     if (char == '(') {
      //       parenDepth++;
      //     } else if (char == ')') {
      //       parenDepth--;
      //     } else if (char == '{') {
      //       braceDepth++;
      //     } else if (char == '}') {
      //       braceDepth--;
      //     }

      //     if (char == ',' && parenDepth == 0 && braceDepth == 0) {
      //       topLevelParts.add(current.toString().trim());
      //       current.clear();
      //     } else {
      //       current.write(char);
      //     }
      //   }
      //   if (current.isNotEmpty) {
      //     topLevelParts.add(current.toString().trim());
      //   }

      //   if (topLevelParts.length == 1) {
      //     return AddressType.p2trMuSig2;
      //   } else {
      //     return AddressType.p2trScriptPathSpending;
      //   }
      // }
    } else {
      throw Exception('Unsupported script type.');
    }
  }
}

///@nodoc
class Checksum {
  static const String _inputCharset =
      '0123456789()[],\'/*abcdefgh@:\$%{}IJKLMNOPQRSTUVWXYZ&+-.;<=>?!^_|~ijklmnopqrstuvwxyzABCDEFGH`#"\\ ';
  static const _checksumCharset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

  static final _generator = [
    0xf5dee51989,
    0xa9fdca3312,
    0x1bab10e32d,
    0x3706b1677a,
    0x644d626ffd
  ];

  static BigInt _calculatePolyMod(List<int> symbols) {
    BigInt chk = BigInt.one;
    for (var value in symbols) {
      var top = chk >> 35;
      chk = (chk & BigInt.from(0x7ffffffff)) << 5 ^ BigInt.from(value);
      for (var i = 0; i < 5; i++) {
        chk ^= (top >> i & BigInt.one) != BigInt.zero
            ? BigInt.from(_generator[i])
            : BigInt.zero;
      }
    }
    return chk;
  }

  static List<int> _transformSymbols(String s) {
    var groups = <int>[];
    var symbols = <int>[];
    for (var c in s.split('')) {
      if (!_inputCharset.contains(c)) {
        return [];
      }
      var v = _inputCharset.indexOf(c);
      symbols.add(v & 31);
      groups.add(v >> 5);
      if (groups.length == 3) {
        symbols.add(groups[0] * 9 + groups[1] * 3 + groups[2]);
        groups = [];
      }
    }
    if (groups.length == 1) {
      symbols.add(groups[0]);
    } else if (groups.length == 2) {
      symbols.add(groups[0] * 3 + groups[1]);
    }
    return symbols;
  }

  static bool isValidChecksum(String s) {
    if (s[s.length - 9] != '#') {
      return false;
    }
    if (!s
        .substring(s.length - 8)
        .split('')
        .every((x) => _checksumCharset.contains(x))) {
      return false;
    }
    var symbols = _transformSymbols(s.substring(0, s.length - 9)).toList()
      ..addAll(s
          .substring(s.length - 8)
          .split('')
          .map((x) => _checksumCharset.indexOf(x)));
    return _calculatePolyMod(symbols) == BigInt.one;
  }

  static String getChecksum(String s) {
    var symbols = _transformSymbols(s).toList();
    var poly =
        _calculatePolyMod(symbols + [0, 0, 0, 0, 0, 0, 0, 0]) ^ BigInt.one;
    var result = List<int>.generate(
      8,
      (i) => ((poly >> (5 * (7 - i))) & BigInt.from(31)).toInt(),
    );

    return result.map((x) => _checksumCharset[x]).join('');
  }
}
