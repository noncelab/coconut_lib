// ignore_for_file: non_constant_identifier_names, constant_identifier_names
part of '../../coconut_lib.dart';

/// Low-level secp256k1 point, ECDSA, Schnorr, and MuSig2 operations.
///
/// Callers are responsible for choosing the correct transaction digest and key
/// representation. Wallet and PSBT APIs are safer entry points for ordinary
/// signing workflows.
///
/// {@category Cryptography and Encoding}
class Ecc {
  static final ZERO32 = Uint8List.fromList(List.generate(32, (index) => 0));
  static final EC_GROUP_ORDER = HEX.decode(
      "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141");
  static final EC_P = HEX.decode(
      "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f");
  static final secp256k1 = ECCurve_secp256k1();
  static final n = secp256k1.n;
  static final G = secp256k1.G;
  static BigInt nDiv2 = n >> 1;
  static const THROW_BAD_PRIVATE = 'Expected Private';
  static const THROW_BAD_POINT = 'Expected Point';
  static const THROW_BAD_TWEAK = 'Expected Tweak';
  static const THROW_BAD_HASH = 'Expected Hash';
  static const THROW_BAD_SIGNATURE = 'Expected Signature';

  static bool isPrivate(Uint8List x) {
    if (!isScalar(x)) return false;
    return _compare(x, ZERO32) > 0 && // > 0
        _compare(x, EC_GROUP_ORDER as Uint8List) < 0; // < G
  }

  static bool isPoint(Uint8List p) {
    if (p.length == 32) {
      return _compare(p, ZERO32) != 0 && _compare(p, EC_P as Uint8List) < 0;
    }
    if (p.length < 33) {
      return false;
    }
    var t = p[0];
    var x = p.sublist(1, 33);

    if (_compare(x, ZERO32) == 0) {
      return false;
    }
    if (_compare(x, EC_P as Uint8List) == 1) {
      return false;
    }
    try {
      decodeFrom(p);
    } catch (err) {
      return false;
    }
    if ((t == 0x02 || t == 0x03) && p.length == 33) {
      return true;
    }
    var y = p.sublist(33);
    if (_compare(y, ZERO32) == 0) {
      return false;
    }
    if (_compare(y, EC_P as Uint8List) == 1) {
      return false;
    }
    if (t == 0x04 && p.length == 65) {
      return true;
    }
    return false;
  }

  static bool isScalar(Uint8List x) {
    return x.length == 32;
  }

  static bool isOrderScalar(Uint8List x) {
    if (!isScalar(x)) return false;
    return _compare(x, EC_GROUP_ORDER as Uint8List) < 0; // < G
  }

  static bool isSignature(Uint8List value) {
    if (value.length != 64) {
      return false;
    }

    Uint8List r = value.sublist(0, 32);
    Uint8List s = value.sublist(32, 64);

    return _compare(r, EC_GROUP_ORDER as Uint8List) < 0 &&
        _compare(s, EC_GROUP_ORDER as Uint8List) < 0;
  }

  static bool _isPointCompressed(Uint8List p) {
    return p[0] != 0x04;
  }

  static bool assumeCompression(bool? value, Uint8List? pubkey) {
    if (value == null && pubkey != null) return _isPointCompressed(pubkey);
    if (value == null) return true;
    return value;
  }

  static Uint8List compressPoint(Uint8List point, {bool isXOnly = false}) {
    ECPoint ecPoint;

    if (point.length == 32) {
      // x-only → assume even y (try 0x02, fallback to 0x03)
      try {
        ecPoint =
            secp256k1.curve.decodePoint(Uint8List.fromList([0x02, ...point]))!;
      } catch (_) {
        ecPoint =
            secp256k1.curve.decodePoint(Uint8List.fromList([0x03, ...point]))!;
      }
    } else if (point.length == 33 || point.length == 65) {
      ecPoint = secp256k1.curve.decodePoint(point)!;
    } else {
      throw ArgumentError(
          "Unsupported public key format (length: ${point.length})");
    }

    if (isXOnly) {
      return ecPoint.getEncoded(false).sublist(1, 33); // x-only
    } else {
      return ecPoint.getEncoded(true); // compressed
    }
  }

  static Uint8List? pointFromScalar(Uint8List d, bool compressed) {
    if (!isPrivate(d)) throw ArgumentError(THROW_BAD_PRIVATE);
    BigInt dd = fromBuffer(d);
    ECPoint pp = (G * dd) as ECPoint;
    if (pp.isInfinity) return null;
    return getEncoded(pp, compressed);
  }

  static Uint8List? pointMultiplyScalar(
      Uint8List p, Uint8List tweak, bool compressed) {
    Uint8List adjustedP =
        (p.length == 32) ? Uint8List.fromList([0x02, ...p]) : p;

    BigInt tt = fromBuffer(tweak);
    ECPoint? pp = (decodeFrom(adjustedP)! * tt) as ECPoint;
    if (pp.isInfinity) return null;
    return getEncoded(pp, compressed);
  }

  static Uint8List? pointCombine(Uint8List p, Uint8List q, bool compressed) {
    if (!isPoint(p)) throw ArgumentError(THROW_BAD_POINT);
    if (!isPoint(q)) throw ArgumentError(THROW_BAD_POINT);

    ECPoint? pp = decodeFrom(p);
    ECPoint? qq = decodeFrom(q);
    ECPoint? pq = (pp! + qq!) as ECPoint;
    if (pq.isInfinity) return null;
    return getEncoded(pq, compressed);
  }

  static Uint8List? pointAddScalar(
      Uint8List p, Uint8List tweak, bool isCompressed) {
    if (!isPoint(p)) throw ArgumentError(THROW_BAD_POINT);
    if (!isOrderScalar(tweak)) throw ArgumentError(THROW_BAD_TWEAK);

    Uint8List adjustedP =
        (p.length == 32) ? Uint8List.fromList([0x02, ...p]) : p;
    bool compressed = assumeCompression(isCompressed, adjustedP);

    ECPoint? pp = decodeFrom(adjustedP);
    if (pp == null || pp.isInfinity) throw ArgumentError("Invalid public key");

    BigInt tt = fromBuffer(tweak);
    if (tt == BigInt.zero) return getEncoded(pp, compressed);

    ECPoint qq = (G * tt)!;
    ECPoint uu = (pp + qq)!;
    if (uu.isInfinity) return null;

    Uint8List encoded = getEncoded(uu, compressed);
    return encoded;
  }

  static Uint8List? pointNegate(Uint8List p) {
    if (!isPoint(p)) throw ArgumentError(THROW_BAD_POINT);

    BigInt fieldPrime = fromBuffer(EC_P as Uint8List);

    ECPoint? P = decodeFrom(p);
    if (P == null || P.isInfinity) return null;

    BigInt? x = P.x!.toBigInteger();
    BigInt? y = P.y!.toBigInteger();
    BigInt negY = (fieldPrime - y!) % fieldPrime;

    ECPoint negP = secp256k1.curve.createPoint(x!, negY);

    bool compressed = _isPointCompressed(p);
    return getEncoded(negP, compressed);
  }

  static Uint8List? privateAdd(Uint8List d, Uint8List tweak) {
    if (!isPrivate(d)) throw ArgumentError(THROW_BAD_PRIVATE);
    if (!isOrderScalar(tweak)) throw ArgumentError(THROW_BAD_TWEAK);
    BigInt dd = fromBuffer(d);
    BigInt tt = fromBuffer(tweak);
    Uint8List dt = toBuffer((dd + tt) % n);

    if (dt.length < 32) {
      Uint8List padLeadingZero = Uint8List(32 - dt.length);
      dt = Uint8List.fromList(padLeadingZero + dt);
    }

    if (!isPrivate(dt)) return null;
    return dt;
  }

  static Uint8List? privateNegate(Uint8List d) {
    if (!isOrderScalar(d)) throw ArgumentError(THROW_BAD_TWEAK);
    BigInt dd = fromBuffer(EC_GROUP_ORDER as Uint8List);
    BigInt tt = fromBuffer(d);
    Uint8List dt = toBuffer((dd - tt) % n);

    if (dt.length < 32) {
      Uint8List padLeadingZero = Uint8List(32 - dt.length);
      dt = Uint8List.fromList(padLeadingZero + dt);
    }

    if (!isPrivate(dt)) return null;
    return dt;
  }

  static Uint8List signEcdsa(Uint8List message, Uint8List secretKey) {
    if (!isScalar(message)) throw ArgumentError(THROW_BAD_HASH);
    if (!isPrivate(secretKey)) throw ArgumentError(THROW_BAD_PRIVATE);
    ECSignature sig = deterministicGenerateK(message, secretKey);
    Uint8List buffer = Uint8List(64);
    buffer.setRange(0, 32, _encodeBigInt(sig.r));
    BigInt s;
    if (sig.s.compareTo(nDiv2) > 0) {
      s = n - sig.s;
    } else {
      s = sig.s;
    }
    buffer.setRange(32, 64, _encodeBigInt(s));
    return buffer;
  }

  static Uint8List signSchnorr(Uint8List message, Uint8List secretKey,
      {Uint8List? auxRand}) {
    if (!isPrivate(secretKey)) throw ArgumentError(THROW_BAD_PRIVATE);
    if (message.length != 32) throw ArgumentError("Message must be 32 bytes");
    if (auxRand != null && auxRand.length != 32) {
      throw ArgumentError("auxRand must be 32 bytes");
    }

    BigInt d0 = fromBuffer(secretKey);
    if (d0 <= BigInt.zero || d0 >= n) {
      throw ArgumentError("Secret key out of range");
    }

    ECPoint? P = G * d0;
    if (P == null || P.isInfinity) {
      throw SigningException(SigningErrorCode.signatureGenerationFailed,
          'Failed to derive a public key for signing.');
    }
    if (P.y!.toBigInteger()!.isOdd) {
      throw SigningException(SigningErrorCode.signatureGenerationFailed,
          'Derived public key has invalid parity for signing.');
    }

    Uint8List P_x = getEncoded(P, false).sublist(1, 33);

    Uint8List aux = auxRand ??
        Uint8List.fromList(
            List.generate(32, (_) => Random.secure().nextInt(256)));
    Uint8List t = Uint8List(32);
    Uint8List hashAux = Hash.taggedHash("BIP0340/aux", aux);
    Uint8List dBytes = toBuffer(d0);
    for (int i = 0; i < 32; i++) {
      t[i] = dBytes[i] ^ hashAux[i];
    }

    Uint8List k0Bytes = Hash.taggedHash(
        "BIP0340/nonce", Uint8List.fromList([...t, ...P_x, ...message]));
    BigInt k0 = fromBuffer(k0Bytes) % n;
    if (k0 == BigInt.zero) {
      throw SigningException(SigningErrorCode.signatureGenerationFailed,
          'Nonce generation produced zero.');
    }

    ECPoint? R = G * k0;
    if (R == null || R.isInfinity) {
      throw SigningException(SigningErrorCode.signatureGenerationFailed,
          'Failed to generate the signature nonce point.');
    }
    if (R.y!.toBigInteger()!.isOdd) {
      k0 = n - k0;
      R = G * k0;
    }

    Uint8List R_x = getEncoded(R, false).sublist(1, 33);

    Uint8List eBytes = Hash.taggedHash(
        "BIP0340/challenge", Uint8List.fromList([...R_x, ...P_x, ...message]));
    BigInt e = fromBuffer(eBytes) % n;

    BigInt s = (k0 + e * d0) % n;

    // Convert s to hex
    Uint8List sBytes = toBuffer(s);
    if (sBytes.length < 32) {
      Uint8List paddedS = Uint8List(32);
      paddedS.setAll(32 - sBytes.length, sBytes);
      sBytes = paddedS;
    } else if (sBytes.length > 32) {
      throw SigningException(SigningErrorCode.signatureGenerationFailed,
          'Generated signature scalar is too large.');
    }

    Uint8List signature = Uint8List.fromList([...R_x, ...sBytes]);

    if (!verifySchnorr(message, getEncoded(P, true), signature)) {
      throw SigningException(SigningErrorCode.signatureGenerationFailed,
          'Generated Schnorr signature failed verification.');
    }

    return signature;
  }

  static bool verifyEcdsa(
      Uint8List message, Uint8List publicKey, Uint8List signature) {
    if (!isScalar(message)) throw ArgumentError(THROW_BAD_HASH);
    if (!isPoint(publicKey)) throw ArgumentError(THROW_BAD_POINT);
    if (!isSignature(signature)) throw ArgumentError(THROW_BAD_SIGNATURE);

    ECPoint? Q = decodeFrom(publicKey);
    BigInt r = fromBuffer(signature.sublist(0, 32));
    BigInt s = fromBuffer(signature.sublist(32, 64));

    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    signer.init(false, PublicKeyParameter(ECPublicKey(Q, secp256k1)));

    return signer.verifySignature(message, ECSignature(r, s));
  }

  static bool verifySchnorr(
      Uint8List message, Uint8List publicKey, Uint8List signature) {
    if (!isScalar(message)) throw ArgumentError(THROW_BAD_HASH);
    if (!isPoint(publicKey)) throw ArgumentError(THROW_BAD_POINT);
    if (!isSignature(signature)) throw ArgumentError(THROW_BAD_SIGNATURE);

    Uint8List R_x = signature.sublist(0, 32);
    Uint8List sBytes = signature.sublist(32, 64);
    BigInt s = fromBuffer(sBytes);

    if (s >= n) {
      return false;
    }

    if (publicKey.length == 32) {
      publicKey = Uint8List.fromList([0x02, ...publicKey]);
    }

    ECPoint? P = decodeFrom(publicKey);
    if (P == null || P.isInfinity) {
      return false;
    }

    Uint8List eBytes = Hash.taggedHash("BIP0340/challenge",
        Uint8List.fromList([...R_x, ...publicKey.sublist(1), ...message]));
    BigInt e = fromBuffer(eBytes) % n;

    ECPoint? R_prime = (G * s)! + (P * (n - e));
    if (R_prime == null || R_prime.isInfinity) {
      return false;
    }

    Uint8List R_prime_x = getEncoded(R_prime, false).sublist(1, 33);
    return R_prime_x.toString() == R_x.toString();
  }

  /// Decode a BigInt from bytes in big-endian encoding.
  static BigInt _decodeBigInt(List<int> bytes) {
    BigInt result = BigInt.from(0);
    for (int i = 0; i < bytes.length; i++) {
      result += BigInt.from(bytes[bytes.length - i - 1]) << (8 * i);
    }
    return result;
  }

  /// Encode a BigInt into bytes using big-endian encoding.
  static Uint8List _encodeBigInt(BigInt number) {
    var byteMask = BigInt.from(0xff);
    final negativeFlag = BigInt.from(0x80);
    int needsPaddingByte;
    int rawSize;

    if (number > BigInt.zero) {
      rawSize = (number.bitLength + 7) >> 3;
      needsPaddingByte =
          ((number >> (rawSize - 1) * 8) & negativeFlag) == negativeFlag
              ? 1
              : 0;

      if (rawSize < 32) {
        needsPaddingByte = 1;
      }
    } else {
      needsPaddingByte = 0;
      rawSize = (number.bitLength + 8) >> 3;
    }

    final size = rawSize < 32 ? rawSize + needsPaddingByte : rawSize;
    var result = Uint8List(size);
    for (int i = 0; i < size; i++) {
      result[size - i - 1] = (number & byteMask).toInt();
      number = number >> 8;
    }
    return result;
  }

  static BigInt fromBuffer(Uint8List d) {
    return _decodeBigInt(d);
  }

  static Uint8List toBuffer(BigInt d) {
    return _encodeBigInt(d);
  }

  static ECPoint? decodeFrom(Uint8List P) {
    return secp256k1.curve.decodePoint(P);
  }

  static Uint8List getEncoded(ECPoint? P, compressed) {
    return P!.getEncoded(compressed);
  }

  static ECSignature deterministicGenerateK(Uint8List hash, Uint8List x) {
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    var pkp = PrivateKeyParameter(ECPrivateKey(_decodeBigInt(x), secp256k1));
    signer.init(true, pkp);
    return signer.generateSignature(hash) as ECSignature;
  }

  static int _compare(Uint8List a, Uint8List b) {
    BigInt aa = fromBuffer(a);
    BigInt bb = fromBuffer(b);
    if (aa == bb) return 0;
    if (aa > bb) return 1;
    return -1;
  }

  static Uint8List signSchnorrForMuSig2(Uint8List secretNonce,
      Uint8List privateKey, SessionContext sessionContext,
      {bool isFullSignature = true}) {
    if (privateKey.length != 32) {
      throw ArgumentError(
          "privateKey must be 32 bytes (got ${privateKey.length})");
    }
    if (secretNonce.length != 97) {
      throw ArgumentError(
          "secret nonce must be 97 bytes (got ${secretNonce.length})");
    }

    Uint8List publicKey = pointFromScalar(privateKey, true)!;

    if (publicKey[0] != 0x02 && publicKey[0] != 0x03) {
      throw SigningException(SigningErrorCode.signatureGenerationFailed,
          'Private key produced an invalid compressed public key.');
    }

    Uint8List Q = getEncoded(sessionContext.aggregateQ, true);
    BigInt b = sessionContext.b;
    ECPoint R = sessionContext.R;
    BigInt e = sessionContext.e;

    Uint8List R_x = getEncoded(R, false).sublist(1, 33);

    e = fromBuffer(Hash.taggedHash(
        "BIP0340/challenge",
        Uint8List.fromList(
            [...R_x, ...Q.sublist(1), ...sessionContext.message])));

    late BigInt a;
    Uint8List L = Hash.taggedHash(
        'KeyAgg list',
        Uint8List.fromList(
            sessionContext.participantPublicKeys.expand((x) => x).toList()));
    Uint8List? secondKey;
    for (int keyIndex = 1;
        keyIndex < sessionContext.participantPublicKeys.length;
        keyIndex++) {
      if (Codec.encodeHex(sessionContext.participantPublicKeys[0]) !=
          Codec.encodeHex(sessionContext.participantPublicKeys[keyIndex])) {
        secondKey = sessionContext.participantPublicKeys[keyIndex];
        break;
      }
    }

    if (secondKey != null &&
        Codec.encodeHex(publicKey) == Codec.encodeHex(secondKey)) {
      a = BigInt.one;
    } else {
      a = fromBuffer(Hash.taggedHash('KeyAgg coefficient', L + publicKey)) % n;
    }

    BigInt g = BigInt.one;
    if (decodeFrom(Q)!.y!.toBigInteger()!.isOdd) {
      g = n - BigInt.one;
    }

    final BigInt d = sessionContext.applyTaprootTweak
        ? ((g * sessionContext.musigGacc * fromBuffer(privateKey)) % n)
        : (g * fromBuffer(privateKey) % n);

    BigInt k1_ =
        Converter.hexToBigDec(Codec.encodeHex(secretNonce.sublist(0, 32)));
    BigInt k2_ =
        Converter.hexToBigDec(Codec.encodeHex(secretNonce.sublist(32, 64)));

    BigInt k1;
    BigInt k2;
    if (R.y!.toBigInteger()!.isOdd) {
      k1 = n - k1_;
      k2 = n - k2_;
    } else {
      k1 = k1_;
      k2 = k2_;
    }

    BigInt s = (k1 + b * k2 + e * a * d) % n;

    Uint8List sBytes = toBuffer(s);
    if (sBytes.length < 32) {
      Uint8List paddedS = Uint8List(32);
      paddedS.setAll(32 - sBytes.length, sBytes);
      sBytes = paddedS;
    } else if (sBytes.length > 32) {
      throw SigningException(SigningErrorCode.signatureGenerationFailed,
          'Generated signature scalar is too large.');
    }

    Uint8List publicNonce = Uint8List.fromList(
        pointFromScalar(toBuffer(k1_), true)! +
            pointFromScalar(toBuffer(k2_), true)!);

    Uint8List fullSignature = Uint8List.fromList([...R_x, ...sBytes]);

    if (!verifyMuSig2PartialSignature(
        fullSignature, publicNonce, publicKey, sessionContext)) {
      throw SigningException(SigningErrorCode.signatureGenerationFailed,
          'Generated MuSig2 partial signature failed verification.');
    }

    if (isFullSignature) {
      return fullSignature;
    } else {
      return sBytes;
    }
  }

  static bool verifyMuSig2PartialSignature(
      Uint8List signature,
      Uint8List publicNonce,
      Uint8List publicKey,
      SessionContext sessionContext) {
    Uint8List prefixedPublicKey = publicKey.length == 32
        ? Uint8List.fromList([0x02, ...publicKey])
        : publicKey;

    ECPoint Q = sessionContext.aggregateQ;
    ECPoint R = sessionContext.R;
    BigInt b = sessionContext.b;
    BigInt e = sessionContext.e;
    final BigInt gacc = sessionContext.applyTaprootTweak
        ? sessionContext.musigGacc
        : BigInt.one;
    late BigInt s;

    if (signature.length == 64) {
      s = fromBuffer(signature.sublist(32, 64));
    } else {
      s = fromBuffer(signature);
    }

    if (s >= n) {
      return false;
    }

    ECPoint R1 = secp256k1.curve.decodePoint(publicNonce.sublist(0, 33))!;
    ECPoint R2 = secp256k1.curve.decodePoint(publicNonce.sublist(33, 66))!;

    ECPoint ReS = (R1 + (R2 * b))!;

    if (R.y!.toBigInteger()!.isOdd) {
      ReS = decodeFrom(pointNegate(getEncoded(ReS, true))!)!;
    }

    final P = secp256k1.curve.decodePoint(prefixedPublicKey)!;

    late BigInt a;
    Uint8List L = Hash.taggedHash(
        'KeyAgg list',
        Uint8List.fromList(
            sessionContext.participantPublicKeys.expand((x) => x).toList()));

    Uint8List? secondKey;
    for (int keyIndex = 1;
        keyIndex < sessionContext.participantPublicKeys.length;
        keyIndex++) {
      if (Codec.encodeHex(sessionContext.participantPublicKeys[0]) !=
          Codec.encodeHex(sessionContext.participantPublicKeys[keyIndex])) {
        secondKey = sessionContext.participantPublicKeys[keyIndex];
        break;
      }
    }

    if (secondKey != null &&
        Codec.encodeHex(prefixedPublicKey) == Codec.encodeHex(secondKey)) {
      a = BigInt.one;
    } else {
      a = fromBuffer(
              Hash.taggedHash('KeyAgg coefficient', L + prefixedPublicKey)) %
          n;
    }

    final g = Q.y!.toBigInteger()!.isOdd ? n - BigInt.one : BigInt.one;
    final g_ = (g * gacc) % n;

    final left = G * s;
    final right = ReS + (P * ((e * a * g_) % n));

    final result = left == right;

    return result;
  }

  static Uint8List getAggregatedSignatureForMuSig2(
    SessionContext sessionContext,
    List<Signature> signatureList,
  ) {
    signatureList.sort((a, b) => a.publicKey.compareTo(b.publicKey));

    ECPoint r = sessionContext.R;
    BigInt e = sessionContext.e;

    Uint8List R_x = getEncoded(r, false).sublist(1, 33);

    BigInt s = BigInt.zero;
    for (int i = 0; i < signatureList.length; i++) {
      Signature partialSig = signatureList[i];
      Uint8List signature = Codec.decodeHex(partialSig.signature);
      BigInt si;
      if (signature.length == 64) {
        si = fromBuffer(signature.sublist(32, 64));
      } else {
        si = fromBuffer(signature);
      }
      s = (s + si) % n;
    }

    BigInt g = BigInt.one;
    if (sessionContext.aggregateQ.y!.toBigInteger()!.isOdd) {
      g = n - BigInt.one;
    }

    if (sessionContext.applyTaprootTweak) {
      s = (s + e * g * sessionContext.musigTacc) % n;
      if (s < BigInt.zero) {
        s += n;
      }
    }
    Uint8List signature =
        Uint8List.fromList(R_x + Converter.bigIntToBytes(s, byteLength: 32));
    // BIP340 uses 32-byte x-only public keys; verifySchnorr normalizes with 0x02.
    Uint8List publicKey =
        Ecc.getEncoded(sessionContext.aggregateQ, true).sublist(1);

    if (!Ecc.verifySchnorr(sessionContext.message, publicKey, signature)) {
      throw SigningException(SigningErrorCode.signatureGenerationFailed,
          'Generated MuSig2 aggregate signature failed verification.');
    }
    return signature;
  }
}
