part of '../../coconut_lib.dart';

/// Represents the balance of a wallet.
class Balance {
  int confirmed;
  int unconfirmed;

  /// @nodoc
  Balance(this.confirmed, this.unconfirmed);

  /// @nodoc
  Balance operator +(Balance other) {
    return Balance(
        confirmed + other.confirmed, unconfirmed + other.unconfirmed);
  }

  /// @nodoc
  String toJson() {
    return jsonEncode({'confirmed': confirmed, 'unconfirmed': unconfirmed});
  }

  /// @nodoc
  factory Balance.fromJson(String jsonStr) {
    Map<String, dynamic> json = jsonDecode(jsonStr);
    return Balance(json['confirmed'], json['unconfirmed']);
  }
}
