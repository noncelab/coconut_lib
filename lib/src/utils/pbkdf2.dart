import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha512.dart';
import 'package:pointycastle/key_derivators/api.dart' show Pbkdf2Parameters;
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

class PBKDF2 {
  static getSeed(String secret, String salt) {
    PBKDF2KeyDerivator derivator =
        PBKDF2KeyDerivator(HMac(SHA512Digest(), 128));

    final saltList = Uint8List.fromList(utf8.encode(salt));
    derivator.reset();
    derivator.init(Pbkdf2Parameters(saltList, 2048, 64));
    var array = derivator.process(Uint8List.fromList(secret.codeUnits));
    return array.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
  }
}
