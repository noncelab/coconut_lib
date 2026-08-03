part of '../../coconut_lib.dart';

/// Represents common utility functions for wallet.
abstract class WalletUtility {
  WalletUtility._();

  /// Get the derivation path for the given address type and account index.
  static String getDerivationPath(AddressType addressType, int accountIndex) {
    bool isTestnet = NetworkType.currentNetworkType.isTestnet;
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
    if (NetworkType.currentNetworkType.isTestnet) {
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
        address.startsWith('2') ||
        address.startsWith('3') ||
        address.startsWith('m') ||
        address.startsWith('n')) {
      if (address.length < 26 || address.length > 35) return false;
      Uint8List decoded;
      try {
        decoded = Codec.decodeBase58(address);
      } catch (e) {
        return false;
      }

      // Check the version byte
      int versionByte = decoded[0];
      if (address.startsWith('1')) {
        if (versionByte != 0x00) {
          return false;
        }
      } else if (address.startsWith('3')) {
        if (versionByte != 0x05) {
          return false;
        }
      } else if (address.startsWith('m') || address.startsWith('n')) {
        if (versionByte != 0x6f) {
          return false;
        }
      } else if (address.startsWith('2')) {
        if (versionByte != 0xc4) {
          return false;
        }
      }
      return true;
    } else if (address.startsWith('bc1p') ||
        address.startsWith('tb1p') ||
        address.startsWith('bcrt1p')) {
      var codec = bech32m.Bech32mCodec().decode(address);
      if (codec.hrp != 'bc' && codec.hrp != 'tb' && codec.hrp != 'bcrt') {
        return false;
      }
      if (codec.data[0] != 1) return false;
      if (codec.data[0] > 16) return false;
      return true;
    } else if (address.startsWith('bc1q') ||
        address.startsWith('tb1q') ||
        address.startsWith('bcrt1q')) {
      try {
        ScriptPublicKey._decodeWitnessV0Program(address);
      } catch (_) {
        return false;
      }
      return true;
    }

    return false;
  }

  /// Check if the given mnemonic word is in the word list.
  static bool isInMnemonicWordList(String word) {
    return english_words.wordList.contains(word);
  }

  /// Check if the given mnemonic is valid.
  static bool validateMnemonic(Uint8List mnemonic) {
    List<String> mnemonicWordsString = utf8.decode(mnemonic).split(' ');
    int wordLength = mnemonicWordsString.length;

    if (wordLength != 12 && wordLength != 24) {
      return false;
    }

    int checksumLength = mnemonicWordsString.length ~/ 3;
    List<int> mnemonicWordBinary = [];
    for (String word in mnemonicWordsString) {
      int index = english_words.wordList.indexOf(word);
      if (index == -1) {
        return false;
      }
      String binary = index.toRadixString(2).padLeft(11, '0');

      for (int i = 0; i < binary.length; i++) {
        mnemonicWordBinary.add(int.parse(binary[i]));
      }
      index = 0;
      binary = '';
    }

    List<int> entropy = mnemonicWordBinary.sublist(
        0, mnemonicWordBinary.length - checksumLength);
    List<int> checkSumBinary = mnemonicWordBinary.sublist(
        mnemonicWordBinary.length - checksumLength, mnemonicWordBinary.length);
    Uint8List body = Converter.binaryToBytes(entropy);
    int target = Converter.binaryToDecimal(
        Converter.bytesToBinary(Hash.sha256fromByte(body))
            .sublist(0, checksumLength));
    int checkSum = Converter.binaryToDecimal(checkSumBinary);

    return target == checkSum;
  }

  static bool validateDerivationPath(String derivationPath) {
    // Updated regex: allows m/ and segments with optional ' or h suffix
    final regex = RegExp(r"^m(\/\d+['h]?)*$");

    if (!regex.hasMatch(derivationPath)) {
      return false;
    }

    final segments = derivationPath.split('/');

    // First segment must be 'm'
    if (segments[0] != 'm') {
      return false;
    }

    for (int i = 1; i < segments.length; i++) {
      final segment = segments[i];

      // Validate: must be digits followed optionally by ' or h
      if (!RegExp(r"^\d+(['h])?$").hasMatch(segment)) {
        return false;
      }

      // Strip suffix and check range
      final numberPart = segment.replaceAll(RegExp(r"['h]"), '');
      final number = int.tryParse(numberPart);

      if (number == null || number < 0 || number >= 0x80000000) {
        return false;
      }
    }

    return true;
  }

  static double satoshiToBitcoin(int satoshi) {
    return satoshi / 100000000.0;
  }

  /// 부동 소숫점 연산 시 오차가 발생할 수 있으므로 Decimal이용
  static int bitcoinToSatoshi(double bitcoin) {
    return (Decimal.parse(bitcoin.toString()) * Decimal.parse('100000000'))
        .toDouble()
        .toInt();
  }

  static int getAccountIndexFromDerivationPath(String derivationPath) {
    List<String> pathList = derivationPath.split('/');
    return int.parse(pathList.last);
  }

  static bool isChangeFromDerivationPath(String derivationPath) {
    List<String> pathList = derivationPath.split('/');
    return pathList[pathList.length - 2] == '1';
  }

  static double estimateVirtualByte(
      AddressType addressType, int numberOfInputs, int numberOfOutputs,
      {int? requiredSignature,
      int? totalSigner,
      bool isScriptPath = false,
      int? leafCount,
      int? tapScriptSize,
      int? totalOutputBytes}) {
    final int baseByte = 12;
    final int inputSize = 41;
    final int outputNonWitnessBytes = totalOutputBytes ?? numberOfOutputs * 34;
    int signatureSize = 73;
    int pubKeySize = 34;

    int nonWitnessSize = baseByte;
    int witnessSize = 1; // number of witness
    if (addressType.isTaproot) {
      signatureSize = 65; // 64 + 1(length)
      pubKeySize = 0; // 32 + 1(length)
    }
    if (addressType == AddressType.p2wpkh) {
      nonWitnessSize += numberOfInputs * inputSize;
      nonWitnessSize += outputNonWitnessBytes;
      witnessSize = numberOfInputs * (signatureSize + pubKeySize + 1);
    } else if (addressType == AddressType.p2wsh) {
      if (requiredSignature == null || totalSigner == null) {
        throw ArgumentError(
            'requiredSignature and totalSignature is required for p2wsh');
      }
      nonWitnessSize += numberOfInputs * inputSize;
      nonWitnessSize += outputNonWitnessBytes;

      // 각 입력당 witness 크기 계산
      for (int i = 0; i < numberOfInputs; i++) {
        witnessSize += 1; // 00
        witnessSize += requiredSignature * signatureSize;
        int scriptSize = 0;
        scriptSize += 3; // m,n,OP_CHECKMULTISIG
        scriptSize += totalSigner * pubKeySize + 1;
        witnessSize += scriptSize;
        witnessSize += totalSigner + 1; //script size
      }
    } else if (addressType == AddressType.p2tr) {
      nonWitnessSize += numberOfInputs * inputSize;
      nonWitnessSize += outputNonWitnessBytes;

      if (!isScriptPath) {
        // Key path spending: 코사이너 키를 몇 개 모았든 MuSig으로 집계되어
        // 최종 서명은 1개뿐이므로 키 개수는 witness 크기에 영향을 주지 않는다.
        witnessSize = numberOfInputs * (signatureSize + 1); // +1: 스택 항목 수
      } else {
        // Script path spending
        if (leafCount == null || tapScriptSize == null) {
          throw ArgumentError(
              'leafCount and tapScriptSize are required for taproot script path');
        }
        final int sigCount = requiredSignature ?? 1; // leaf가 요구하는 서명 수

        final int merklePathLen = _estimateTaprootMerklePath(leafCount);
        final int controlBlockSize = 33 + 32 * merklePathLen;

        final int tapScriptElementSize =
            Codec.encodeVariableInteger(tapScriptSize).length + tapScriptSize;
        final int controlBlockElementSize =
            Codec.encodeVariableInteger(controlBlockSize).length +
                controlBlockSize;

        witnessSize = 0;
        for (int i = 0; i < numberOfInputs; i++) {
          witnessSize += 1; // 스택 항목 수
          witnessSize += sigCount * signatureSize; // 서명들 (각 65)
          witnessSize += tapScriptElementSize; // tapscript
          witnessSize += controlBlockElementSize; // control block
        }
      }
    } else {
      throw Exception('Unsupported address type');
    }

    double vByte = ((nonWitnessSize * 4) + witnessSize) / 4;
    return vByte;
  }

  /// taproot script path의 control block 크기 계산을 위해 spend되는 leaf의
  /// merkle path 깊이를 추정한다.
  ///
  /// 이 라이브러리의 taptree 구성은 한 레벨의 노드 수가 홀수일 때 마지막 노드를
  /// 해싱 없이 다음 레벨로 승격시키므로, leaf의 merkle path 길이는 어느 leaf를
  /// spend하는지에 따라 달라진다. 수수료 추정에서는 "마지막 leaf"를 가정한다.
  static int _estimateTaprootMerklePath(int leafCount) {
    if (leafCount <= 1) return 0;
    int pathLen = 0;
    int levelSize = leafCount;
    while (levelSize > 1) {
      if (levelSize.isEven) pathLen += 1;
      levelSize = (levelSize + 1) ~/ 2; // ceil(n/2)
    }
    return pathLen;
  }

  bool compareUint8List(Uint8List list1, Uint8List list2) {
    if (list1.length != list2.length) {
      return false;
    }
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) {
        return false;
      }
    }

    return true;
  }
}
