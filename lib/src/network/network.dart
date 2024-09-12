part of '../../coconut_lib.dart';

abstract class Network {
  SocketConnectionStatus get connectionStatus;

  int get gapLimit => 20;
  int get reqId;
  Block get block;

  Future<Result<String, CoconutError>> broadcast(String rawTransaction);

  Future<Result<WalletFetchResult, CoconutError>> fullSync(WalletBase wallet);

  Future<Result<int, CoconutError>> getNetworkMinimumFeeRate();

  void fetchBlock();

  Future<Block> fetchBlockSync();

  Future<Result<String, CoconutError>> getTransaction(String txHash);
}
