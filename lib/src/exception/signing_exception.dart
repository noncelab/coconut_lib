part of '../../coconut_lib.dart';

/// Stable machine-readable signing failure codes.
enum SigningErrorCode {
  /// The signer has no seed or private key for the requested operation.
  privateKeyUnavailable,

  /// Required MuSig2 public or secret nonce material is unavailable.
  nonceUnavailable,

  /// The selected key store is not a signer for the input.
  signerMismatch,

  /// A generated or supplied signature fails verification.
  invalidSignature,

  /// Signature generation failed an internal cryptographic check.
  signatureGenerationFailed,
}

/// Failure while creating or coordinating a signature.
///
/// {@category Errors}
class SigningException extends CoconutException<SigningErrorCode> {
  /// Creates a signing or signing-coordination failure.
  SigningException(super.code, super.message, {super.cause, super.context});
}
