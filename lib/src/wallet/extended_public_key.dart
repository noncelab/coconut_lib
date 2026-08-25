part of '../../coconut_lib.dart';

/// Represents an extended public key of a wallet.
class ExtendedPublicKey {
  final int _depth;
  final Uint8List _parentFingerprint;
  final int _index;
  final Uint8List _chainCode;
  final Uint8List _publicKey;
  final int _version;

  /// @nodoc
  ExtendedPublicKey(this._depth, this._parentFingerprint, this._index,
      this._chainCode, this._publicKey, this._version);

  /// The depth of the extended public key.
  int get depth => _depth;

  /// @nodoc
  Uint8List get parentFingerprintByte => _parentFingerprint;

  /// The parent fingerprint of the extended public key.
  String get parentFingerprint => Codec.encodeHex(_parentFingerprint);

  /// The index of the extended public key.
  int get index => _index;

  /// @nodoc
  Uint8List get chainCode => _chainCode;

  /// @nodoc
  Uint8List get publicKey => _publicKey;

  /// The version of the extended public key.
  int get version => _version;

  /// Create an extended public key from a hierarchical deterministic wallet.
  factory ExtendedPublicKey.fromHdWallet(
      HDWallet wallet, int version, Uint8List fingerprint) {
    return ExtendedPublicKey(wallet.depth, fingerprint, wallet.index,
        wallet.chainCode, wallet.publicKey, version);
  }

  factory ExtendedPublicKey.fromPublicKey(
      Uint8List publicKey,
      Uint8List chainCode,
      int version,
      Uint8List fingerprint,
      String derivationPath) {
    int depth = derivationPath.split("/").length - 1;
    int index;
    String lastIndexStr = derivationPath.split("/").last;
    if (lastIndexStr.endsWith("'")) {
      index = int.parse(lastIndexStr.substring(0, lastIndexStr.length - 1)) +
          hightstBit;
    } else {
      index = int.parse(lastIndexStr);
    }
    return ExtendedPublicKey(
        depth, fingerprint, index, chainCode, publicKey, version);
  }

  // factory HDWallet.fromPublicKeyWithDerivationPath(
  //     Uint8List publicKey, Uint8List chainCode, String derivationPath) {
  //   if (!Ecc.isPoint(publicKey)) {
  //     throw ArgumentError("Point is not on the curve");
  //   }
  //   HDWallet wallet = HDWallet(null, publicKey, chainCode);
  //   wallet.depth = derivationPath.split("/").length - 1;
  //   String lastIndexStr = derivationPath.split("/").last;
  //   if (lastIndexStr.endsWith("'")) {
  //     wallet._index =
  //         int.parse(lastIndexStr.substring(0, lastIndexStr.length - 1)) +
  //             hightstBit;
  //   } else {
  //     wallet._index = int.parse(lastIndexStr);
  //   }

  //   return wallet;
  // }

  /// Parse an extended public key.
  ///
  /// Network compatibility is validated by default. Set [validateNetwork] to
  /// `false` when parsing independently of [NetworkType.currentNetworkType].
  factory ExtendedPublicKey.parse(String expub, {bool validateNetwork = true}) {
    if (validateNetwork && NetworkType.currentNetworkType.isTestnet) {
      if (!expub.toLowerCase().startsWith("tpub") &&
          !expub.toLowerCase().startsWith("vpub") &&
          !expub.toLowerCase().startsWith("Vpub")) {
        throw Exception(
            "Extended public key is not compatible with the network type.");
      }
    } else if (validateNetwork) {
      if (!expub.toLowerCase().startsWith("xpub") &&
          !expub.toLowerCase().startsWith("zpub") &&
          !expub.toLowerCase().startsWith("Zpub")) {
        throw Exception(
            "Extended public key is not compatible with the network type.");
      }
    }
    Uint8List buffer = Codec.decodeBase58(expub);
    if (buffer.length != 78) {
      throw const FormatException(
          'Invalid extended public key payload length.');
    }
    ByteData bytes = buffer.buffer.asByteData();
    var version = bytes.getUint32(0);
    // 1 byte: depth: 0x00 for master nodes, 0x01 for level-1 descendants, ...
    var depth = buffer[4];

    // 4 bytes: the fingerprint of the parent's key (0x00000000 if master key)
    //var parentFingerprint = bytes.getUint32(5);
    Uint8List fingerprint = Uint8List.fromList(buffer.sublist(5, 9));
    if (depth == 0) {
      if (!fingerprint.every((b) => b == 0)) {
        throw const FormatException(
            'Master extended public key has a parent fingerprint.');
      }
    }

    var index = bytes.getUint32(9);
    if (depth == 0 && index != 0) {
      throw const FormatException(
          'Master extended public key has a child index.');
    }

    Uint8List chainCode = buffer.sublist(13, 45);
    Uint8List publicKey = buffer.sublist(45, 78);
    return ExtendedPublicKey(
        depth, fingerprint, index, chainCode, publicKey, version);
  }

  /// Serialize the extended public key.
  String serialize({bool toXpub = false}) {
    Uint8List buffer = Uint8List(78);
    ByteData bytes = buffer.buffer.asByteData();
    if (toXpub) {
      if (NetworkType.currentNetworkType.isTestnet) {
        bytes.setUint32(0, 0x043587CF);
      } else {
        bytes.setUint32(0, 0x0488B21E);
      }
    } else {
      bytes.setUint32(0, version);
    }
    bytes.setUint8(4, depth);
    bytes.setUint32(5, parentFingerprintByte.buffer.asByteData().getUint32(0));
    bytes.setUint32(9, index);
    buffer.setRange(13, 45, chainCode);
    buffer.setRange(45, 78, publicKey);

    Uint8List hash =
        Uint8List.fromList(Hash.sha256fromByte(Hash.sha256fromByte(buffer)));
    Uint8List combine = Uint8List.fromList(
        [buffer, hash.sublist(0, 4)].expand((i) => i).toList(growable: false));
    return Codec.encodeBase58(combine);
  }

  String serializeForPsbt({bool toXpub = false}) {
    Uint8List buffer = Uint8List(78);
    ByteData bytes = buffer.buffer.asByteData();
    if (toXpub) {
      if (NetworkType.currentNetworkType.isTestnet) {
        bytes.setUint32(0, 0x043587CF);
      } else {
        bytes.setUint32(0, 0x0488B21E);
      }
    } else {
      bytes.setUint32(0, version);
    }
    bytes.setUint8(4, depth);
    bytes.setUint32(5, parentFingerprintByte.buffer.asByteData().getUint32(0));
    bytes.setUint32(9, index);
    buffer.setRange(13, 45, chainCode);
    if (publicKey.length != 33) {
      throw ArgumentError(
          'Public key must be 33 bytes, got ${publicKey.length}');
    }
    buffer.setRange(45, 78, publicKey);

    return Codec.encodeHex(buffer);
  }

  @override
  String toString() {
    return serialize();
  }

  @override
  bool operator ==(Object other) {
    if (other is ExtendedPublicKey) {
      return serialize() == other.serialize();
    }
    return false;
  }

  @override
  int get hashCode => serialize().hashCode;
}
