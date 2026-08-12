part of '../../coconut_lib.dart';

/// Represents the base class of a wallet and vault.
///
/// {@category Wallets and Keys}
abstract class WalletBase {
  final AddressType _addressType;
  final String _derivationPath;
  final int _accountIndex = 0;
  late final Descriptor _descriptor;

  /// Get the address type of the wallet.
  AddressType get addressType => _addressType;

  /// Get the derivation path of the wallet.
  String get derivationPath => _derivationPath;

  /// Get the account index of the wallet.
  int get accountIndex => _accountIndex;

  /// Get the descriptor of the wallet.
  String get descriptor => _descriptor.serialize();

  /// @nodoc
  WalletBase(this._addressType, this._derivationPath);

  /// Get the address of the given index.
  String getAddress(int addressIndex, {bool isChange = false});

  /// Get the address from derivation path
  String getAddressWithDerivationPath(String derivationPath);

  /// Returns descriptor key-origin expressions for this wallet's signers.
  String getKeyOriginExpression();

  /// Whether at least one wallet key is referenced by [psbt].
  bool hasPublicKeyInPsbt(String psbt);

  /// Adds every signature available to this wallet or vault to [psbt].
  String addSignatureToPsbt(String psbt);
}
