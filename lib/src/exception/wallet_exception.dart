part of '../../coconut_lib.dart';

/// Stable machine-readable wallet failure codes.
enum WalletErrorCode {
  networkMismatch,
  derivationPathMismatch,
  missingMetadata,
}

/// Failure caused by wallet configuration or ownership mismatch.
class WalletException extends CoconutException<WalletErrorCode> {
  WalletException(super.code, super.message, {super.cause, super.context});
}
