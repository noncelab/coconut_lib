part of '../../coconut_lib.dart';

/// Stable machine-readable transaction failure codes.
enum TransactionErrorCode {
  /// Available inputs cannot cover the requested outputs and fee.
  insufficientFunds,

  /// An output is below the applicable dust threshold.
  dustOutput,

  /// The same outpoint was supplied more than once.
  duplicateUtxo,

  /// A requested UTXO is not present in the transaction or its metadata.
  utxoNotFound,

  /// The transaction violates an internal structural invariant.
  invalidTransaction,
}

/// Failure while constructing or mutating a Bitcoin transaction.
///
/// {@category Errors}
class TransactionException extends CoconutException<TransactionErrorCode> {
  /// Creates a transaction failure identified by [code].
  TransactionException(super.code, super.message, {super.cause, super.context});
}
