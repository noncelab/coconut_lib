part of '../../coconut_lib.dart';

/// Stable machine-readable transaction failure codes.
enum TransactionErrorCode {
  insufficientFunds,
  dustOutput,
  duplicateUtxo,
  utxoNotFound,
  invalidTransaction,
}

/// Failure while constructing or mutating a Bitcoin transaction.
class TransactionException extends CoconutException<TransactionErrorCode> {
  TransactionException(super.code, super.message, {super.cause, super.context});
}
