import 'dart:convert';
import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';
import 'converter.dart';

class Hash {
  static String sha256(String input) {
    var bytes = utf8.encode(input);
    var digest = SHA256Digest().process(bytes);
    return Converter.bytesToHex(digest);
  }

  static String sha256fromHex(String hex) {
    Uint8List decoded = Uint8List.fromList(HEX.decode(hex));
    var hashed = SHA256Digest().process(decoded);
    return Converter.bytesToHex(hashed);
  }

  static Uint8List sha256fromByte(Uint8List bytes) {
    return SHA256Digest().process(bytes);
  }

  static String hmacSha512(String key, String data) {
    var hmacSha512 = HMac(SHA512Digest(), 128)
      ..init(KeyParameter(utf8.encode(key))); // HMAC-SHA-512 생성

    // var hmacSha512 =
    //     crypto.Hmac(crypto.sha512, utf8.encode(key)); // HMAC-SHA-512 생성
    var digest =
        hmacSha512.process(utf8.encode(data)); // 데이터에 대한 HMAC-SHA-512 계산
    return digest.toString(); // 계산된 해시를 문자열로 반환
  }

  static Uint8List hmacSha512FromList(Uint8List key, Uint8List data) {
    var hmacSha512 = HMac(SHA512Digest(), 128)
      ..init(KeyParameter(key)); // HMAC-SHA-512 생성
    // var hmacSha512 = crypto.Hmac(crypto.sha512, key); // HMAC-SHA-512 생성
    var digest = hmacSha512.process(data); // 데이터에 대한 HMAC-SHA-512 계산
    return digest; // 계산된 해시를 문자열로 반환
  }

  static Uint8List sha160fromHex(String hex) {
    var decoded = Uint8List.fromList(HEX.decode(hex));
    final hashed = sha256fromByte(decoded);
    // final hashed = crypto.sha256.convert(decoded);
    final ripemd = RIPEMD160Digest().process(hashed);
    return ripemd;
  }

  static Uint8List sha160fromByte(Uint8List hex) {
    final hashed = sha256fromByte(hex);
    // final hashed = crypto.sha256.convert(decoded);
    final ripemd = RIPEMD160Digest().process(hashed);
    return ripemd;
  }

  /// Returns the first 4 bytes of the SHA256 hashed value as uint.
  static int getSimpleHash(String input) {
    final hex = utf8.encode(input);
    final d = SHA256Digest();

    var hash = d.process(Uint8List.fromList(hex));

    return hash.buffer.asByteData().getUint32(0);
  }
}
