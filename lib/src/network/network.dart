part of '../../coconut_lib.dart';

/// @nodoc
abstract class Network {
  SocketConnectionStatus get connectionStatus;

  int get gapLimit => 20;
  int get reqId;
  BlockTimestamp get block;

  Future<Result<String, CoconutError>> broadcast(String rawTransaction);

  Future<Result<WalletStatus, CoconutError>> fullSync(WalletBase wallet);

  Future<Result<int, CoconutError>> getNetworkMinimumFeeRate();

  void fetchBlock();

  Future<BlockTimestamp> fetchBlockSync();

  Future<Result<String, CoconutError>> getTransaction(String txHash);
}
