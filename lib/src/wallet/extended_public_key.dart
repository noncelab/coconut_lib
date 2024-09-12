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
  String get parentFingerprint => Converter.bytesToHex(_parentFingerprint);

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

  /// Parse an extended public key.
  factory ExtendedPublicKey.parse(String expub) {
    Uint8List buffer = Base58.decode(expub);
    if (buffer.length != 78) {
      throw Exception("ExtendedPublicKey :Invalid buffer length");
    }
    ByteData bytes = buffer.buffer.asByteData();
    var version = bytes.getUint32(0);
    // 1 byte: depth: 0x00 for master nodes, 0x01 for level-1 descendants, ...
    var depth = buffer[4];

    // 4 bytes: the fingerprint of the parent's key (0x00000000 if master key)
    //var parentFingerprint = bytes.getUint32(5);
    Uint8List fingerprint = Uint8List.fromList(buffer.sublist(5, 9));
    if (depth == 0) {
      if (fingerprint != [0, 0, 0, 0, 0]) {
        throw Exception("HDWallet :Invalid parent fingerprint");
      }
    }

    var index = bytes.getUint32(9);
    if (depth == 0 && index != 0) throw Exception("HDWallet : Invalid index");

    Uint8List chainCode = buffer.sublist(13, 45);
    Uint8List publicKey = buffer.sublist(45, 78);
    return ExtendedPublicKey(
        depth, fingerprint, index, chainCode, publicKey, version);
  }

  /// Serialize the extended public key.
  String serialize() {
    Uint8List buffer = Uint8List(78);
    ByteData bytes = buffer.buffer.asByteData();
    bytes.setUint32(0, version);
    bytes.setUint8(4, depth);
    bytes.setUint32(5, parentFingerprintByte.buffer.asByteData().getUint32(0));
    bytes.setUint32(9, index);
    buffer.setRange(13, 45, chainCode);

    buffer.setRange(45, 78, publicKey);

    Uint8List hash =
        Uint8List.fromList(Hash.sha256fromByte(Hash.sha256fromByte(buffer)));
    Uint8List combine = Uint8List.fromList(
        [buffer, hash.sublist(0, 4)].expand((i) => i).toList(growable: false));
    return Base58.encode(combine);
  }
}
