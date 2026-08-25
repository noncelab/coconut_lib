part of '../../coconut_lib.dart';

/// Stable machine-readable wallet failure codes.
enum WalletErrorCode {
  /// Key or descriptor network does not match the configured network.
  networkMismatch,

  /// A derivation path is invalid or belongs to another account.
  derivationPathMismatch,

  /// Wallet metadata required by the operation is absent.
  missingMetadata,
}

/// Failure caused by wallet configuration or ownership mismatch.
///
/// {@category Errors}
class WalletException extends CoconutException<WalletErrorCode> {
  /// Creates a wallet configuration or ownership failure.
  WalletException(super.code, super.message, {super.cause, super.context});
}
