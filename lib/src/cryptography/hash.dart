part of '../../coconut_lib.dart';
// import 'dart:convert';
// import 'dart:typed_data';

// import 'package:hex/hex.dart';
// import 'package:pointycastle/export.dart';
// import 'codec.dart';

/// Bitcoin-oriented hashing and key-derivation primitives.
///
/// {@category Cryptography and Encoding}
class Hash {
  Hash._();

  /// Returns SHA-256 of the UTF-8 encoded [input].
  static Uint8List sha256(String input) {
    var bytes = utf8.encode(input);
    var digest = SHA256Digest().process(bytes);
    return digest;
  }

  /// Returns SHA-256 of hexadecimal input as hexadecimal output.
  static String sha256fromHex(String hex) {
    Uint8List decoded = Uint8List.fromList(HEX.decode(hex));
    var hashed = SHA256Digest().process(decoded);
    return Codec.encodeHex(hashed);
  }

  /// Returns SHA-256 of [bytes].
  static Uint8List sha256fromByte(Uint8List bytes) {
    return SHA256Digest().process(bytes);
  }

  /// Computes HMAC-SHA512 for [data] using [key].
  static Uint8List hmacSha512(Uint8List key, Uint8List data) {
    var hmacSha512 = HMac(SHA512Digest(), 128)
      ..init(KeyParameter(key)); // HMAC-SHA-512 생성
    // var hmacSha512 = crypto.Hmac(crypto.sha512, key); // HMAC-SHA-512 생성
    var digest = hmacSha512.process(data); // 데이터에 대한 HMAC-SHA-512 계산
    return digest; // 계산된 해시를 문자열로 반환
  }

  /// Computes HASH160 (SHA-256 then RIPEMD-160) of hexadecimal input.
  static Uint8List sha160fromHex(String hex) {
    var decoded = Uint8List.fromList(HEX.decode(hex));
    final hashed = sha256fromByte(decoded);
    // final hashed = crypto.sha256.convert(decoded);
    final ripemd = RIPEMD160Digest().process(hashed);
    return ripemd;
  }

  /// Computes HASH160 (SHA-256 then RIPEMD-160) of bytes.
  static Uint8List sha160fromByte(Uint8List hex) {
    final hashed = sha256fromByte(hex);
    // final hashed = crypto.sha256.convert(decoded);
    final ripemd = RIPEMD160Digest().process(hashed);
    return ripemd;
  }

  /// Derives a 64-byte BIP39 seed using PBKDF2-HMAC-SHA512.
  static Uint8List pbkdf2(Uint8List secret, Uint8List salt) {
    PBKDF2KeyDerivator derivator =
        PBKDF2KeyDerivator(HMac(SHA512Digest(), 128));

    derivator.reset();
    derivator.init(Pbkdf2Parameters(salt, 2048, 64));
    // var array =
    //     derivator.process(Uint8List.fromList(utf8.decode(secret).codeUnits));
    // return array.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
    return derivator.process(Uint8List.fromList(utf8.decode(secret).codeUnits));
  }

  /// Computes the BIP340 tagged hash of [data] under [tag].
  static Uint8List taggedHash(String tag, List<int> data) {
    var tagByte = Hash.sha256fromByte(utf8.encode(tag));
    var tagHash = Uint8List.fromList(tagByte + tagByte);
    var taggedHash = Hash.sha256fromByte(Uint8List.fromList(tagHash + data));
    return taggedHash;
  }

  /// Computes the BIP341 TapTweak hash for an internal key and Merkle root.
  static Uint8List hashTapTweak(
      String tag, Uint8List pubkey, Uint8List? merkleRoot) {
    List<int> combined;
    if (merkleRoot == null) {
      combined = pubkey;
    } else {
      combined = pubkey + merkleRoot;
    }
    Uint8List hashTapTweak = taggedHash(tag, combined);
    return hashTapTweak;
  }
}
