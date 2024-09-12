part of '../../coconut_lib.dart';

/// Represents common feature of single signature and multisignature vault.
abstract class VaultFeature {
  /// Check if the vault can sign to the given psbt.
  bool canSignToPsbt(String psbt);

  /// Add signature to the given psbt.
  String addSignatureToPsbt(String psbt);
}
