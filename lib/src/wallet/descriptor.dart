part of '../../coconut_lib.dart';

/// Represents a descriptor of Bitcoin. (BIP-0380)
class Descriptor {
  String _scriptType;
  List<String> _publicKeyList = [];
  int requiredSignatures = 1;

  /// @nodoc
  Descriptor(this._scriptType, this._publicKeyList,
      {this.requiredSignatures = 1});

  /// The total number of signatures. (for multisig)
  int get totalSignature => _publicKeyList.length;

  /// Script type of the descriptor.
  String get scriptType => _scriptType;

  /// Create a descriptor for a single signature.
  factory Descriptor.forSingleSignature(String scriptType, String publicKey,
      String derivationPath, String fingerprint) {
    //[98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDV
    if (scriptType == 'wsh-in-sh') {
      return Descriptor(
          'sh-wpkh', ["[$fingerprint/$derivationPath]$publicKey/<0;1>/*"]);
    } else {
      return Descriptor(
          scriptType, ["[$fingerprint/$derivationPath]$publicKey/<0;1>/*"]);
    }
  }

  /// Create a descriptor for multisignature.
  factory Descriptor.forMultisignature(
      String scriptType,
      List<String> publicKeyList,
      String derivationPath,
      List<String> fingerprintList,
      int requiredSignatures) {
    //'wsh(sortedmulti(2,[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*,[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*,[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*))#x9cc762c';
    List<String> publicKeyString = [];
    for (int i = 0; i < publicKeyList.length; i++) {
      publicKeyString.add(
          "[${fingerprintList[i]}/$derivationPath]${publicKeyList[i]}/<0;1>/*");
    }
    return Descriptor(scriptType, publicKeyString,
        requiredSignatures: requiredSignatures);
  }

  /// Parse the descriptor.
  factory Descriptor.parse(String descriptor) {
    if (!Checksum.isValidChecksum(descriptor)) {
      throw Exception('Invalid descriptor format.');
    }
    var withoutChecksum = descriptor.split('#')[0];
    RegExpMatch scriptTypeMatch =
        RegExp(r'(\w+)\((.+)\)').firstMatch(withoutChecksum)!;

    String scriptType = scriptTypeMatch.group(1)!;
    String scriptContent = scriptTypeMatch.group(2)!;
    List<String> pubKeyContent = [];

    int require = 1;
    if (scriptType == 'wsh' || scriptType == 'sh') {
      RegExpMatch isMultisigMatch =
          RegExp(r'(\w+)\((.+)\)').firstMatch(scriptContent)!;
      if (isMultisigMatch.group(1) == 'multi' ||
          isMultisigMatch.group(1) == 'sortedmulti') {
        String multisigContent = isMultisigMatch.group(2)!;
        require = int.parse(multisigContent.split(',')[0]);
        pubKeyContent = multisigContent.split(',').sublist(1);
      } else if (isMultisigMatch.group(1) == 'wpkh') {
        scriptType = '$scriptType-wpkh';
        RegExpMatch isNestedMatch =
            RegExp(r'(\w+)\((.+)\)').firstMatch(scriptContent)!;
        pubKeyContent.add(isNestedMatch.group(2)!.split(',')[0]);
      }
    } else {
      pubKeyContent.add(scriptContent);
    }

    return Descriptor(scriptType, pubKeyContent, requiredSignatures: require);
  }

  /// Get the derivation path.
  String getDerivationPath(int index) {
    String pub = _publicKeyList[index];
    RegExpMatch derivationPathMatch = RegExp(r'\[(.+)\](.+)').firstMatch(pub)!;
    List<String> list = derivationPathMatch.group(1)!.split('/').sublist(1);
    String derivationPath = 'm/${list.join('/')}';

    return derivationPath;
  }

  /// Get the fingerprint.
  String getFingerprint(int index) {
    String pub = _publicKeyList[index];
    RegExpMatch derivationPathMatch = RegExp(r'\[(.+)\](.+)').firstMatch(pub)!;
    String? fingerprint = derivationPathMatch.group(1)!.split('/')[0];
    return fingerprint;
  }

  /// Get the public key.
  String getPublicKey(int index) {
    String pub = _publicKeyList[index];
    RegExpMatch derivationPathMatch = RegExp(r'\[(.+)\](.+)').firstMatch(pub)!;
    String? pubkey = derivationPathMatch.group(2)!.split('/')[0];

    return pubkey;
  }

  /// Serialize the descriptor.
  String serialize() {
    String body = '';
    if (scriptType == 'sh-wpkh') {
      body = "sh(wpkh(${_publicKeyList[0]}))";
    } else if (scriptType != 'wsh' && scriptType != 'sh') {
      body = "$_scriptType(${_publicKeyList[0]})";
    } else {
      body = "$_scriptType(sortedmulti($requiredSignatures";
      for (String pub in _publicKeyList) {
        body += ",$pub";
      }
      body += "))";
    }
    return '$body#${Checksum.getChecksum(body)}';
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
