part of '../../coconut_lib.dart';

/// Represents the common feature of a wallet.
abstract class WalletFeature {
  /// Get the balance of the wallet.
  int getBalance();

  /// Get the unconfirmed balance of the wallet.
  int getUnconfirmedBalance();

  /// Get transfer information of the wallet.
  List<Transfer> getTransferList({int cursor = 0, int count = 5});

  /// Get the list of unspent transaction outputs of the wallet.
  List<UTXO> getUtxoList({UtxoOrderEnum order = UtxoOrderEnum.byTimestampDesc});

  /// Generate PSBT for sending bitcoin.
  Future<String> generatePsbt(
      String receiverAddress, int sendingAmount, int feeRate);

  /// Generate PSBT for sending all bitcoin in the wallet.
  Future<String> generatePsbtWithMaximum(String receiverAddress, int feeRate);

  /// Get a estimate fee for sending bitcoin.
  Future<int> estimateFee(
      String receiverAddress, int sendingAmount, int feeRate);

  /// Get a estimate fee for sending all bitcoin in the wallet.
  Future<int> estimateFeeWithMaximum(String receiverAddress, int feeRate);

  /// Fetch the blockchain data of the wallet.
  Future<void> fetchOnChainData(NodeConnector nodeConnector);

  /// Save wallet status to the file.
  void saveStatus();

  /// Load wallet status from the file.
  Future<void> loadStatus();

  WalletStatus? get walletStatus;
}
