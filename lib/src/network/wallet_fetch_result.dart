part of '../../coconut_lib.dart';

class WalletFetchResult {
  List<TransactionEntity> txEntityList;
  List<UtxoEntity> utxoEntityList;
  BalanceEntity balanceEntity;
  Map<int, BlockHeaderEntity> blockEntityMap;
  Map<int, Map<int, int>> addressBalanceMap;
  Map<int, List<int>> usedIndexList;
  Map<int, int> maxGapMap;
  int initialReceiveIndex;
  int initialChangeIndex;

  WalletFetchResult(
      {required this.txEntityList,
      required this.utxoEntityList,
      required this.balanceEntity,
      required this.blockEntityMap,
      required this.addressBalanceMap,
      required this.usedIndexList,
      required this.maxGapMap,
      this.initialReceiveIndex = 0,
      this.initialChangeIndex = 0});
}
