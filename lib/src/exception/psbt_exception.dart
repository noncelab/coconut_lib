part of '../../coconut_lib.dart';

/// Stable machine-readable PSBT failure codes.
enum PsbtErrorCode {
  transactionInputMismatch,
  invalidPsbt,
  policyMismatch,
  utxoMismatch,
  invalidSignature,
  insufficientSignatures,
  missingMetadata,
  derivationPathMismatch,
  signerMismatch,
  duplicateUtxo,
  invalidTransaction,
}

/// Failure while validating, signing, or finalizing a PSBT.
class PsbtException extends CoconutException<PsbtErrorCode> {
  final int? inputIndex;

  PsbtException(super.code, super.message,
      {this.inputIndex, super.cause, Map<String, Object?> context = const {}})
      : super(
            context: inputIndex == null
                ? context
                : <String, Object?>{'inputIndex': inputIndex, ...context});
}
