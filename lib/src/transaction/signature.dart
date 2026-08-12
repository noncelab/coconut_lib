part of '../../coconut_lib.dart';

/// A public key and its serialized transaction signature.
///
/// {@category Transactions}
class Signature {
  final String _signature;
  final String _publicKey;

  Signature(this._signature, this._publicKey);

  String get signature => _signature;
  String get publicKey => _publicKey;
}
