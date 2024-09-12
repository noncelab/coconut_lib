part of '../../coconut_lib.dart';

/// Represents a transaction output.
class TransactionOutput {
  Uint8List _amount;
  ScriptPublicKey _scriptPubKey;

  /// Get the amount of the output.
  int get amount =>
      Converter.bytesToDec(Uint8List.fromList(_amount.reversed.toList()));

  /// Get the script public key object of the transaction output.
  ScriptPublicKey get scriptPubKey => _scriptPubKey;

  /// The length of the transaction output.
  int get length => _amount.length + _scriptPubKey.length;

  /// @nodoc
  TransactionOutput(this._amount, this._scriptPubKey);

  /// Get the Bitcoin amount of the output.
  void setAmount(int amount) {
    _amount = Converter.intToLittleEndianBytes(amount, 8);
  }

  factory TransactionOutput.forSending(int amount, String address) {
    Uint8List amountBytes = Converter.intToLittleEndianBytes(amount, 8);
    if (address.startsWith('1') ||
        address.startsWith('m') ||
        address.startsWith('n')) {
      return TransactionOutput(amountBytes, ScriptPublicKey.p2pkh(address));
    } else if (address.startsWith('bc1') ||
        address.startsWith('tb1') ||
        address.startsWith('bcrt1')) {
      return TransactionOutput(amountBytes, ScriptPublicKey.p2wpkh(address));
    }
    throw Exception('AddressType not supported');
  }

  /// Parse the transaction output from the given output hex.
  factory TransactionOutput.parse(String output) {
    Uint8List bytes = Converter.hexToBytes(output);

    var amount = bytes.sublist(0, 8);
    var script = bytes.sublist(8, bytes.length);
    ScriptPublicKey scriptPubKey =
        ScriptPublicKey.parse(Converter.bytesToHex(script));

    return TransactionOutput(amount, scriptPubKey);
  }

  /// Serialize the transaction output.
  String serialize() {
    //print("amount : " + Converter.bytesToHex(_amount));
    //print(amount);
    //print("scriptPubKey : " + _scriptPubKey.serialize());
    return Converter.bytesToHex(_amount) + _scriptPubKey.serialize();
  }

  /// Get the address of the transaction output.
  String getAddress() {
    return _scriptPubKey.getAddress();
  }
}
