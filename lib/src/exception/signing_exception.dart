part of '../../coconut_lib.dart';

/// Stable machine-readable signing failure codes.
enum SigningErrorCode {
  privateKeyUnavailable,
  nonceUnavailable,
  signerMismatch,
  invalidSignature,
  signatureGenerationFailed,
}

/// Failure while creating or coordinating a signature.
class SigningException extends CoconutException<SigningErrorCode> {
  SigningException(super.code, super.message, {super.cause, super.context});
}
