part of '../../coconut_lib.dart';

/// Represents an UTXO.
class UTXO {
  String _transactionHash;
  int _index;
  int _amount;
  String _derivationPath;
  int _timestamp;
  int _blockHeight;

  /// @nodoc
  UTXO(
    this._transactionHash,
    this._index,
    this._amount,
    this._derivationPath,
    this._timestamp,
    this._blockHeight,
  );

  /// Get the previous transaction hash of this UTXO.
  String get transactionHash => _transactionHash;

  /// Get the index of the previous transaction.
  int get index => _index;

  /// Get the amount of the UTXO.
  int get amount => _amount;

  /// Get the derivation path of the UTXO.
  String get derivationPath => _derivationPath;

  /// Get the timestamp of the UTXO.
  int get timestamp => _timestamp;

  /// Get the block height of the UTXO.
  int get blockHeight => _blockHeight;

  /// @nodoc
  factory UTXO.fromRepository(UtxoEntity utxo) {
    return UTXO(
      utxo.txHash,
      utxo.index,
      utxo.amount,
      utxo.derivationPath,
      utxo.timestamp,
      utxo.height,
    );
  }
}
