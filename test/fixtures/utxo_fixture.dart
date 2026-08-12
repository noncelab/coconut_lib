import 'package:coconut_lib/coconut_lib.dart';

abstract final class UtxoFixture {
  static const receiveAddress = 'bcrt1qxdyjf6h5d6qxap4n2dap97q4j5ps6ua8jkxz0z';

  static Utxo common(AddressType addressType) {
    final derivationPath = WalletUtility.getDerivationPath(addressType, 0);
    return Utxo('0' * 64, 0, 100000, '$derivationPath/0/0');
  }

  static Utxo create(
      {int amount = 100000,
      String derivationPath = "m/84'/1'/0'/0/0",
      String entropy = 'default-utxo'}) {
    return Utxo(
        Codec.encodeHex(Hash.sha256(entropy)), 0, amount, derivationPath);
  }

  static List<Utxo> list(
      {int count = 10, String derivationPath = "m/84'/1'/0'/0/0"}) {
    return List.generate(
        count,
        (index) =>
            create(entropy: 'utxo #$index', derivationPath: derivationPath));
  }

  static List<Utxo> taprootList(
      {int count = 10, String derivationPath = "m/86'/1'/0'/0/0"}) {
    return List.generate(
        count,
        (index) =>
            create(entropy: 'utxo #$index', derivationPath: derivationPath));
  }
}
