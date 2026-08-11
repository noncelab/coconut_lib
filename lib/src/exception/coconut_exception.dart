part of '../../coconut_lib.dart';

/// Stable machine-readable error codes for recoverable Coconut failures.
enum CoconutErrorCode {
  insufficientFunds,
  dustOutput,
  duplicateUtxo,
  utxoNotFound,
  transactionInputMismatch,
  invalidTransaction,
  invalidPsbt,
  policyMismatch,
  utxoMismatch,
  invalidSignature,
  insufficientSignatures,
  missingMetadata,
  networkMismatch,
  derivationPathMismatch,
  descriptorMismatch,
  privateKeyUnavailable,
  nonceUnavailable,
  signerMismatch,
  signatureGenerationFailed,
}

/// Base class for recoverable, domain-specific failures from Coconut APIs.
///
/// Malformed serialized input uses [FormatException], invalid API arguments use
/// [ArgumentError]/[RangeError], and invalid object state uses [StateError].
class CoconutException implements Exception {
  final CoconutErrorCode code;
  final String message;
  final Object? cause;
  final Map<String, Object?> context;

  CoconutException(this.code, this.message,
      {this.cause, Map<String, Object?> context = const {}})
      : context = Map.unmodifiable(context);

  @override
  String toString() {
    final details = context.isEmpty ? '' : ' $context';
    return '$runtimeType(${code.name}): $message$details';
  }
}

/// Failure while constructing or mutating a Bitcoin transaction.
class TransactionException extends CoconutException {
  TransactionException(super.code, super.message, {super.cause, super.context});
}

/// Failure while validating, signing, or finalizing a PSBT.
class PsbtException extends CoconutException {
  final int? inputIndex;

  PsbtException(super.code, super.message,
      {this.inputIndex, super.cause, Map<String, Object?> context = const {}})
      : super(
            context: inputIndex == null
                ? context
                : <String, Object?>{'inputIndex': inputIndex, ...context});
}

/// Failure caused by wallet configuration or ownership mismatch.
class WalletException extends CoconutException {
  WalletException(super.code, super.message, {super.cause, super.context});
}

/// Failure while creating or coordinating a signature.
class SigningException extends CoconutException {
  SigningException(super.code, super.message, {super.cause, super.context});
}
