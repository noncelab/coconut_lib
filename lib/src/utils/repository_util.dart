part of '../../coconut_lib.dart';

class RepositoryUtil {
  static int getUniqueId(List<String> args) {
    String combinedParams = args.join(':');
    return Hash.getSimpleHash(combinedParams);
  }

  static int getBlockUniqueId(int height) {
    return getUniqueId(['block', '$height']);
  }

  static int getTxUniqueId(int walletId, String txHash) {
    return getUniqueId(['transaction', '$walletId', txHash]);
  }

  static int getUtxoUniqueId(String txHash, int index) {
    return getUniqueId(['utxo', txHash, '$index']);
  }
}
