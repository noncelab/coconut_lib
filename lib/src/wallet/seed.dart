part of '../../coconut_lib.dart';

/// Represents a seed.
///
/// {@category Wallets and Keys}
class Seed {
  Uint8List _mnemonic = Uint8List.fromList([]); // 12 or 24 words
  Uint8List _passphrase = utf8.encode('');

  /// The mnemonic words of the seed.
  Uint8List get mnemonic => _mnemonic;

  /// The passphrase of the seed.
  Uint8List get passphrase => _passphrase;

  /// The root seed of the seed.
  Uint8List get rootSeed => _getRootSeed();

  Seed._(Uint8List mnemonic, Uint8List passphrase) {
    _mnemonic = mnemonic;
    _passphrase = passphrase;
  }

  /// Create a seed from random entropy.
  factory Seed.random({int mnemonicLength = 24, Uint8List? passphrase}) {
    if (mnemonicLength < 12 || mnemonicLength > 24 || mnemonicLength % 3 != 0) {
      throw Exception('MnemonicLength is not valid.');
    }
    int digit = (mnemonicLength ~/ 3 * 32) ~/ 8;

    Random random = Random.secure();
    Uint8List hexEntropy = Uint8List.fromList(
        List<int>.generate(digit, (_) => random.nextInt(256)));

    return Seed._(_generateMnemonicFromEntropy(hexEntropy),
        passphrase ?? utf8.encode(''));
  }

  /// Create a seed from entropy.
  factory Seed.fromEntropy(Uint8List entropy, {Uint8List? passphrase}) {
    if (entropy.length != 16 && entropy.length != 32) {
      throw (Exception("Seed : 32 or 64 hex entropy supported."));
    }

    return Seed._(
        _generateMnemonicFromEntropy(entropy), passphrase ?? utf8.encode(''));
  }

  /// Create a seed from mnemonic.
  factory Seed.fromMnemonic(Uint8List mnemonic, {Uint8List? passphrase}) {
    if (!WalletUtility.validateMnemonic(mnemonic)) {
      throw Exception('Seed : Invalid mnemonic words.');
    }

    return Seed._(mnemonic, passphrase ?? utf8.encode(''));
  }

  // ///@deprecated
  // factory Seed.fromJson(String json) {
  //   Map<String, dynamic> map = jsonDecode(json);
  //   return Seed._(map['mnemonic'], map['passphrase']);
  // }

  static Uint8List _generateMnemonicFromEntropy(Uint8List entropy) {
    int checksumLength = (entropy.length * 4 ~/ 16).toInt();

    List<int> binaryEntropy = Converter.bytesToBinary(entropy);

    List<int> checksum = Converter.bytesToBinary(Hash.sha256fromByte(entropy))
        .sublist(0, checksumLength);

    List<int> entropyWithChecksum = [...binaryEntropy, ...checksum];

    int mnemonicLength = (entropyWithChecksum.length ~/ 11).toInt();

    List<int> mnemonicIndex = [];

    for (int i = 0, j = 0; j < mnemonicLength; i += 11, j++) {
      mnemonicIndex.add(
          int.parse(entropyWithChecksum.sublist(i, i + 11).join(''), radix: 2));
    }

    final words = english_words.wordList;

    List<String> mnemonicWords = [];

    for (int index in mnemonicIndex) {
      final word = words.elementAt(index);
      mnemonicWords.add(word);
    }

    Uint8List mnemonic = utf8.encode(mnemonicWords.join(' '));

    for (int i = 0; i < mnemonicWords.length; i++) {
      mnemonicWords[i] = '';
    }

    for (int i = 0; i < mnemonicIndex.length; i++) {
      mnemonicIndex[i] = 0;
    }

    for (int i = 0; i < entropyWithChecksum.length; i++) {
      entropyWithChecksum[i] = 0;
    }

    mnemonicWords.clear();
    mnemonicIndex.clear();
    entropyWithChecksum.clear();

    return mnemonic;
  }

  Uint8List _getRootSeed() {
    String passphraseString = utf8.decode(passphrase);
    Uint8List salt =
        Uint8List.fromList(utf8.encode('mnemonic$passphraseString'));
    passphraseString = '';
    return Hash.pbkdf2(mnemonic, salt);
  }

  // ///@deprecated
  // String toJson() {
  //   return jsonEncode({'mnemonic': _mnemonic, 'passphrase': _passphrase});
  // }

  @override
  bool operator ==(Object other) {
    if (other is Seed) {
      return Codec.encodeHex(_getRootSeed()) ==
          Codec.encodeHex(other._getRootSeed());
    }
    return false;
  }

  @override
  int get hashCode {
    return Codec.encodeHex(Hash.sha256fromByte(_getRootSeed())).hashCode;
  }

  /// Securely wipes sensitive data by overwriting with zeros
  void wipe() {
    if (_mnemonic.isNotEmpty) {
      _mnemonic.fillRange(0, _mnemonic.length, 0);
    }

    if (_passphrase.isNotEmpty) {
      _passphrase.fillRange(0, _passphrase.length, 0);
    }

    // Reset to empty lists
    _mnemonic = Uint8List.fromList([]);
    _passphrase = Uint8List.fromList([]);
  }
}
