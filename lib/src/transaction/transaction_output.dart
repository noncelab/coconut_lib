part of '../../coconut_lib.dart';

/// Represents a transaction output.
///
/// {@category Transactions}
class TransactionOutput {
  static const int maxMoney = 21000000 * 100000000;

  Uint8List _amount;
  ScriptPublicKey _scriptPubKey;
  String? derivationPath;
  bool? isChangeOutput;

  /// Get the amount of the output.
  int get amount =>
      Converter.bytesToDec(Uint8List.fromList(_amount.reversed.toList()));

  /// Get the script public key object of the transaction output.
  ScriptPublicKey get scriptPubKey => _scriptPubKey;

  /// The length of the transaction output.
  int get length => _amount.length + _scriptPubKey.length;

  /// @nodoc
  TransactionOutput(Uint8List amount, this._scriptPubKey,
      {this.derivationPath, this.isChangeOutput})
      : _amount = _validateAmountBytes(amount);

  factory TransactionOutput.forPayment(int amount, String address,
      {String? derivationPath, bool isChangeOutput = false}) {
    Uint8List amountBytes =
        Converter.intToLittleEndianBytes(_validateAmount(amount), 8);
    if (address.startsWith('1') ||
        address.startsWith('m') ||
        address.startsWith('n')) {
      return TransactionOutput(amountBytes, ScriptPublicKey.p2pkh(address),
          derivationPath: derivationPath, isChangeOutput: isChangeOutput);
    } else if (address.startsWith('3') || address.startsWith('2')) {
      return TransactionOutput(amountBytes, ScriptPublicKey.p2sh(address),
          derivationPath: derivationPath, isChangeOutput: isChangeOutput);
    } else if (address.startsWith('bc1q') ||
        address.startsWith('tb1q') ||
        address.startsWith('bcrt1q')) {
      return TransactionOutput(
          amountBytes, ScriptPublicKey._fromSegwitV0Address(address),
          derivationPath: derivationPath, isChangeOutput: isChangeOutput);
    } else if (address.startsWith('bc1p') ||
        address.startsWith('tb1p') ||
        address.startsWith('bcrt1p')) {
      return TransactionOutput(amountBytes, ScriptPublicKey.p2tr(address),
          derivationPath: derivationPath, isChangeOutput: isChangeOutput);
    }
    throw Exception('AddressType not supported');
  }

  bool isDustOutput(bool isSegwit, {int dustRelayFee = 3}) {
    int outputScriptSize = Codec.decodeHex(serialize()).length;
    late int inputSize;
    if (isSegwit) {
      inputSize = (32 + 4 + 1 + (107 / 4).floor() + 4);
    } else {
      inputSize = (32 + 4 + 1 + 107 + 4);
    }
    int dustThreshold = dustRelayFee * (outputScriptSize + inputSize);

    if (dustThreshold >= amount) {
      return true;
    }
    return false;
  }

  /// Parse the transaction output from the given output hex.
  factory TransactionOutput.parse(String output) {
    Uint8List bytes = Codec.decodeHex(output);
    if (bytes.length < 10) {
      throw const FormatException('Truncated transaction output.');
    }
    var amount = bytes.sublist(0, 8);
    var script = bytes.sublist(8, bytes.length);
    ScriptPublicKey scriptPubKey =
        ScriptPublicKey.parse(Codec.encodeHex(script));

    return TransactionOutput(amount, scriptPubKey);
  }

  /// Get the Bitcoin amount of the output.
  void setAmount(int amount) {
    _amount = Converter.intToLittleEndianBytes(_validateAmount(amount), 8);
  }

  static int _validateAmount(int amount) {
    if (amount < 0 || amount > maxMoney) {
      throw RangeError.range(amount, 0, maxMoney, 'amount');
    }
    return amount;
  }

  static Uint8List _validateAmountBytes(Uint8List amount) {
    if (amount.length != 8) {
      throw ArgumentError.value(amount.length, 'amount',
          'Transaction output amount must be exactly 8 bytes.');
    }
    final int value = Converter.littleEndianToInt(amount);
    _validateAmount(value);
    return Uint8List.fromList(amount);
  }

  /// Serialize the transaction output.
  String serialize() {
    //print("amount : " + Converter.bytesToHex(_amount));
    //print(amount);
    //print("scriptPubKey : " + _scriptPubKey.serialize());
    return Codec.encodeHex(_amount) + _scriptPubKey.serialize();
  }

  /// Get the address of the transaction output.
  String getAddress() {
    return _scriptPubKey.getAddress();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true; // Check if they are the same instance
    }
    if (other is! TransactionOutput) {
      return false; // Ensure the object is of the same type
    }
    return amount == other.amount &&
        scriptPubKey.serialize() ==
            other.scriptPubKey.serialize(); // Compare properties
  }

  @override
  int get hashCode => amount.hashCode ^ scriptPubKey.hashCode;
}
