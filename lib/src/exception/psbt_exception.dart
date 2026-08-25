part of '../../coconut_lib.dart';

/// Stable machine-readable PSBT failure codes.
enum PsbtErrorCode {
  /// PSBT input count differs from the unsigned transaction input count.
  transactionInputMismatch,

  /// The PSBT is structurally invalid for the requested operation.
  invalidPsbt,

  /// Script or wallet policy metadata does not match the expected policy.
  policyMismatch,

  /// Prevout amount, script, transaction ID, or output index does not match.
  utxoMismatch,

  /// A contained signature is malformed or fails verification.
  invalidSignature,

  /// Finalization was requested before the signing threshold was reached.
  insufficientSignatures,

  /// Required PSBT metadata is absent.
  missingMetadata,

  /// A BIP32 derivation does not belong to the expected account or key.
  derivationPathMismatch,

  /// The declared signer set does not match the wallet or policy.
  signerMismatch,

  /// Multiple PSBT inputs spend the same outpoint.
  duplicateUtxo,

  /// The embedded unsigned transaction is invalid.
  invalidTransaction,
}

/// Failure while validating, signing, or finalizing a PSBT.
///
/// {@category Errors}
class PsbtException extends CoconutException<PsbtErrorCode> {
  /// Zero-based input associated with the failure, if input-specific.
  final int? inputIndex;

  /// Creates a PSBT failure and includes [inputIndex] in [context] when set.
  PsbtException(super.code, super.message,
      {this.inputIndex, super.cause, Map<String, Object?> context = const {}})
      : super(
            context: inputIndex == null
                ? context
                : <String, Object?>{'inputIndex': inputIndex, ...context});
}
