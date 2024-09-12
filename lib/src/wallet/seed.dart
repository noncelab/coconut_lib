part of '../../coconut_lib.dart';

/// Represents a seed.
class Seed {
  late String _entropy;
  List<String> _mnemonic = [];
  String _passphrase = '';

  /// The mnemonic words of the seed.
  String get mnemonic => _getMnemonic();

  /// The passphrase of the seed.
  String get passphrase => _passphrase;

  /// The root seed of the seed.
  String get rootSeed => utf8.decode(_getRootSeed());

  Seed._(
      {String entropy = '',
      List<String> mnemonic = const [],
      String passphrase = ''}) {
    _mnemonic = mnemonic;
    _passphrase = passphrase;
    _entropy = entropy;

    if (_mnemonic.isEmpty && _entropy != '') {
      _setMnemonic();
    }
    //_createHdWallet();
  }

  /// Create a seed from random entropy.
  factory Seed.random({mnemonicLength = 24, passphrase = ''}) {
    if (mnemonicLength <= 12 &&
        mnemonicLength >= 24 &&
        mnemonicLength % 3 != 0) {
      throw Exception('Seed : MnemonicLength is not valid.');
    }
    int digit = (mnemonicLength ~/ 3 * 32) ~/ 8;

    Random random = Random.secure();
    List<int> bytes = List<int>.generate(digit, (_) => random.nextInt(256));
    String hexEntropy =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

    return Seed._(entropy: hexEntropy, passphrase: passphrase);
  }

  factory Seed.fromHexadecimalEntropy(String entropy,
      {String passphrase = ''}) {
    if (entropy.length != 32 && entropy.length != 64) {
      throw (Exception("Seed : 32 or 64 hex entropy supported."));
    }

    return Seed._(entropy: entropy, passphrase: passphrase);
  }

  factory Seed.fromBinaryEntropy(String binEntropy, {String passphrase = ''}) {
    if (binEntropy.length != 128 && binEntropy.length != 256) {
      throw (Exception("Seed : 128 or 256 binary entropy supported."));
    }
    // print(Converter.binToHex(binEntropy));
    return Seed.fromHexadecimalEntropy(Converter.binToHex(binEntropy),
        passphrase: passphrase);
  }

  factory Seed.fromMnemonic(String mnemonicString, {String passphrase = ''}) {
    if (!WalletUtility.validateMnemonic(mnemonicString)) {
      throw Exception('Seed : Invalid mnemonic words.');
    }
    List<String> mnemonic = mnemonicString.split(' ');
    final words = english_words.wordList;
    String binaryMnemonic = '';
    for (String word in mnemonic) {
      int index = words.indexOf(word);
      if (index == -1) {
        throw Exception('Seed : Invalid mnemonic words.');
      }

      String binIndex = Converter.decToBin(index).padLeft(11, '0');
      binaryMnemonic = binaryMnemonic + binIndex;
    }

    return Seed._(mnemonic: mnemonic, passphrase: passphrase);
  }

  void _setMnemonic() {
    if (_entropy == '' || _entropy.isEmpty) {
      throw (Exception("Seed : No entropy."));
    }

    // print(_entropy.length);

    int checksumLength = (_entropy.length * 4 ~/ 32).toInt();

    String checksum = Converter.hexToBin(Hash.sha256fromHex(_entropy))
        .substring(0, checksumLength);
    //.padLeft(8, '0');
    String binEntropy = Converter.hexToBin(_entropy);

    String fullBin = binEntropy + checksum;

    // print(binEntropy.length);
    // print(checksum.length);
    int mnemonicLength = (fullBin.length ~/ 11).toInt();

    List<String> mnemonicIndex = [];

    for (int i = 0, j = 0; j < mnemonicLength; i += 11, j++) {
      mnemonicIndex.add((fullBin).substring(i, i + 11));
    }

    final words = english_words.wordList;

    List<String> mnemonicWords = [];

    for (String index in mnemonicIndex) {
      final word = words.elementAt(Converter.binToDec(index));
      mnemonicWords.add(word);
    }

    if (!WalletUtility.validateMnemonic(mnemonicWords.join(' '))) {
      throw Exception("Seed : Invalid mnemonic words.");
    }

    _mnemonic = mnemonicWords;
  }

  String _getMnemonic() {
    if (_mnemonic.isEmpty) {
      _setMnemonic();
    }

    return _mnemonic.join(' ');
  }

  Uint8List _getRootSeed() {
    return utf8.encode(PBKDF2.getSeed(_getMnemonic(), 'mnemonic$passphrase'));
  }

  ///@nodoc
  String toJson() {
    return jsonEncode({
      'entropy': _entropy,
      'mnemonic': _mnemonic,
      'passphrase': _passphrase
    });
  }

  ///@nodoc
  factory Seed.fromJson(String json) {
    Map<String, dynamic> map = jsonDecode(json);
    return Seed._(
        entropy: map['entropy'],
        mnemonic: List<String>.from(map['mnemonic']),
        passphrase: map['passphrase']);
  }
}
