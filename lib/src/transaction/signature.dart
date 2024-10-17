part of '../../coconut_lib.dart';

class Signature {
  final String _signature;
  final String _publicKey;

  Signature(this._signature, this._publicKey);

  String get signature => _signature;
  String get publicKey => _publicKey;
}
