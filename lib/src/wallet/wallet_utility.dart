part of '../../coconut_lib.dart';

/// Represents common utility functions for wallet.
abstract class WalletUtility {
  WalletUtility._();

  /// Get the derivation path for the given address type and account index.
  static String getDerivationPath(AddressType addressType, int accountIndex) {
    bool isTestnet = BitcoinNetwork.currentNetwork.isTestnet;
    String derivationPath;
    if (addressType == AddressType.p2sh) {
      derivationPath = "m/${addressType.purposeIndex}'";
    } else if (addressType == AddressType.p2wsh) {
      derivationPath =
          "m/${addressType.purposeIndex}'/${isTestnet ? 1 : 0}'/$accountIndex'/2'";
    } else {
      derivationPath =
          "m/${addressType.purposeIndex}'/${isTestnet ? 1 : 0}'/$accountIndex'";
    }

    return derivationPath;
  }

  /// Check if the given address is valid.
  static bool validateAddress(String address) {
    if (BitcoinNetwork.currentNetwork.isTestnet) {
      if (address.startsWith('1') ||
          address.startsWith('3') ||
          address.startsWith('bc1')) {
        return false;
      }
    } else {
      if (address.startsWith('m') ||
          address.startsWith('n') ||
          address.startsWith('2') ||
          address.startsWith('tb1') ||
          address.startsWith('bcrt1')) {
        return false;
      }
    }
    if (address.startsWith('1') ||
        address.startsWith('3') ||
        address.startsWith('m') ||
        address.startsWith('n')) {
      if (address.length < 26 || address.length > 35) return false;
      Uint8List decoded;
      try {
        decoded = Base58.decode(address);
      } catch (e) {
        return false;
      }
      int versionByte = decoded[0];
      if (versionByte != 0x00 && versionByte != 0x05) return false;
      return true;
    } else if (address.startsWith('bc1p') || address.startsWith('tb1p')) {
      var codec = bech32m.Bech32mCodec().decode(address);
      if (codec.hrp != 'bc' && codec.hrp != 'tb') return false;
      if (codec.data[0] != 1) return false;
      if (codec.data[0] > 16) return false;
      return true;
    } else if (address.startsWith('bc1q') ||
        address.startsWith('tb1q') ||
        address.startsWith('bcrt1q')) {
      var codec = Bech32Codec().decode(address);
      if (codec.hrp != 'bc' && codec.hrp != 'tb' && codec.hrp != 'bcrt') {
        return false;
      }
      if (codec.data.isEmpty || codec.data[0] > 16) return false;
      if (codec.data.length < 2 || codec.data.length > 40) return false;
      return true;
    }

    return false;
  }

  /// Check if the given mnemonic is valid.
  static bool validateMnemonic(String mnemonicList) {
    List<String> mnemonic = mnemonicList.split(' ');

    final words = english_words.wordList;
    String binaryMnemonic = '';
    for (String word in mnemonic) {
      int index = words.indexOf(word);
      if (index < 0) {
        return false;
      }
      String binIndex = Converter.decToBin(index).padLeft(11, '0');
      binaryMnemonic = binaryMnemonic + binIndex;
    }

    //validate mnemonic
    return _validateChecksum(binaryMnemonic);
  }

  static bool _validateChecksum(String fullBinary) {
    // print("full : " + fullBinary.length.toString());
    int wordLength = (fullBinary.length ~/ 11);
    // print("wordLength : " + wordLength.toString());

    int checksumLength = wordLength ~/ 3;
    // print("checksumLength : " + checksumLength.toString());

    String body = fullBinary.substring(0, fullBinary.length - checksumLength);
    String checkSum = fullBinary.substring(
        fullBinary.length - checksumLength, fullBinary.length);

    // print("body : " + Converter.binToHex(body));
    // print("hash : " +
    //     Converter.bytesToBin(Hash.sha256fromByte(Converter.binToBytes(body))));
    String target =
        (Converter.bytesToBin(Hash.sha256fromByte(Converter.binToBytes(body))))
            .substring(0, checksumLength);

    // print("checksum : " + checkSum + " target : " + target);
    if (checkSum == target) {
      return true;
    } else {
      return false;
    }
  }
}
