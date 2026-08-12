import 'package:coconut_lib/coconut_lib.dart';

import 'utxo_fixture.dart';
import 'wallet_fixture.dart';

abstract final class PsbtFixture {
  static Psbt p2wpkhUnsigned() {
    final vault = WalletFixture.p2wpkhVault();
    final transaction = Transaction.forSinglePayment(
        UtxoFixture.list(
            count: 1, derivationPath: '${vault.derivationPath}/0/0'),
        vault.getAddress(1),
        '${vault.derivationPath}/1/1',
        15000,
        3,
        vault);
    return Psbt.fromTransaction(transaction, vault);
  }

  static Psbt p2wpkhSigned() {
    final vault = WalletFixture.p2wpkhVault();
    return _signed(p2wpkhUnsigned(), vault);
  }

  static Psbt p2wshUnsigned() {
    final vault = WalletFixture.p2wshVault();
    final transaction = Transaction.forSinglePayment(
        UtxoFixture.list(
            count: 2, derivationPath: '${vault.derivationPath}/0/0'),
        vault.getAddress(1),
        '${vault.derivationPath}/1/1',
        15000,
        3,
        vault);
    return Psbt.fromTransaction(transaction, vault);
  }

  static Psbt p2wshSigned() {
    final vault = WalletFixture.p2wshVault();
    return _signed(p2wshUnsigned(), vault);
  }

  static Psbt p2trKeyPathUnsigned() {
    final vault = WalletFixture.p2trKeyPathVault();
    final transaction = Transaction.forSinglePayment(
        UtxoFixture.taprootList(
            count: 1, derivationPath: '${vault.derivationPath}/0/0'),
        vault.getAddress(1),
        '${vault.derivationPath}/1/1',
        15000,
        3,
        vault);
    return Psbt.fromTransaction(transaction, vault);
  }

  static Psbt p2trKeyPathSigned() {
    final vault = WalletFixture.p2trKeyPathVault();
    return _signed(p2trKeyPathUnsigned(), vault);
  }

  static Psbt _signed(Psbt psbt, WalletBase vault) {
    return Psbt.parse(vault.addSignatureToPsbt(psbt.serialize()));
  }
}
