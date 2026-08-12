part of '../../coconut_lib.dart';

/// Represents an UTXO.
///
/// {@category Wallets and Keys}
class Utxo {
  static const int maxOutputIndex = 0xffffffff;
  static const int maxMoney = 21000000 * 100000000;

  final String _transactionHash;
  final int _index;
  final int _amount;
  final String _derivationPath;

  /// @nodoc
  Utxo(
    String transactionHash,
    int index,
    int amount,
    this._derivationPath,
  )   : _transactionHash = _validateTransactionHash(transactionHash),
        _index = _validateIndex(index),
        _amount = _validateAmount(amount) {
    if (!WalletUtility.validateDerivationPath(_derivationPath)) {
      throw Exception("Invalid derivation path (e.g., m/44'/0'/0'/0/0)");
    }
  }

  static String _validateTransactionHash(String transactionHash) {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(transactionHash)) {
      throw FormatException(
          'Transaction hash must be a 32-byte hexadecimal string.');
    }
    return transactionHash;
  }

  static int _validateIndex(int index) {
    if (index < 0 || index > maxOutputIndex) {
      throw RangeError.range(index, 0, maxOutputIndex, 'index');
    }
    return index;
  }

  static int _validateAmount(int amount) {
    if (amount < 0 || amount > maxMoney) {
      throw RangeError.range(amount, 0, maxMoney, 'amount');
    }
    return amount;
  }

  /// Get the transaction hash of this UTXO.
  String get transactionHash => _transactionHash;

  /// Get the index of the transaction output.
  int get index => _index;

  /// Get the amount of the UTXO.
  int get amount => _amount;

  /// Get the derivation path of the UTXO.
  String get derivationPath => _derivationPath;

  // Get account index from derivation path.
  int get accountIndex {
    return WalletUtility.getAccountIndexFromDerivationPath(_derivationPath);
  }

  // Is this UTXO is a change output.
  bool get isChange {
    return WalletUtility.isChangeFromDerivationPath(_derivationPath);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Utxo &&
        other._transactionHash == _transactionHash &&
        other._index == _index;
  }

  @override
  int get hashCode => _transactionHash.hashCode ^ _index.toString().hashCode;
}
