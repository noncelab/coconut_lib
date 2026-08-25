Low-level primitives for Bitcoin encoding, hashing, and secp256k1 operations.

- [Codec](../coconut_lib/Codec-class.html) handles hexadecimal, CompactSize, Base58, and WIF encodings.
- [Converter](../coconut_lib/Converter-class.html) handles endian, integer, and signature representations.
- [Hash](../coconut_lib/Hash-class.html) provides Bitcoin-oriented hashes and tagged hashes.
- [Ecc](../coconut_lib/Ecc-class.html) provides ECDSA, Schnorr, point, and MuSig2 operations.

Most applications should use the wallet, transaction, and PSBT APIs instead of
calling these primitives directly. Inputs are binary-format sensitive and must
be validated at trust boundaries.
