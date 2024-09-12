part of '../../coconut_lib.dart';

/// Represents the balance of a wallet.
class Balance {
  final int _confirmed;
  final int _unconfirmed;

  /// The confirmed balance of the wallet.
  int get confirmed => _confirmed;

  /// The unconfirmed balance of the wallet.
  int get unconfirmed => _unconfirmed;

  /// @nodoc
  Balance(this._confirmed, this._unconfirmed);

  /// @nodoc
  Balance operator +(Balance other) {
    return Balance(
        _confirmed + other.confirmed, _unconfirmed + other.unconfirmed);
  }
}
