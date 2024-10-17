part of '../../coconut_lib.dart';

/// Wallet status from the Bitcoin node.
class WalletStatus {
  /// List of wallet related transactions.
  List<Transaction> transactionList = [];

  /// List of UTXOs of the wallet
  List<UTXO> utxoList;

  /// Wallet balance
  Balance balance;

  /// Wallet related Block headers
  Map<int, BlockHeader> blockHeaderMap;

  ///index - balance map of receive address
  Map<int, int> receiveAddressBalanceMap;

  ///index - balance map of change address
  Map<int, int> changeAddressBalanceMap;

  /// used index list of receive address
  List<int> receiveUsedIndexList;

  /// used index list of change address
  List<int> changeUsedIndexList;

  /// max gap of receive address index
  int receiveMaxGap;

  /// max gap of change address index
  int changeMaxGap;

  /// @nodoc
  int initialReceiveIndex;

  /// @nodoc
  int initialChangeIndex;
  DateTime fetcherTime = DateTime.now();

  /// get the transaction with the given transaction hash
  Transaction getTransaction(String txHash) {
    return transactionList.firstWhere((tx) => tx.transactionHash == txHash);
  }

  WalletStatus(
      {required this.transactionList,
      required this.utxoList,
      required this.balance,
      required this.blockHeaderMap,
      required this.receiveAddressBalanceMap,
      required this.changeAddressBalanceMap,
      required this.receiveUsedIndexList,
      required this.changeUsedIndexList,
      required this.receiveMaxGap,
      required this.changeMaxGap,
      this.initialReceiveIndex = 0,
      this.initialChangeIndex = 0});

  /// @nodoc
  String toJson() {
    return jsonEncode({
      'transactionList': transactionList.map((e) => e.toJson()).toList(),
      'utxoList': utxoList.map((e) => e.toJson()).toList(),
      'balance': balance.toJson(),
      'blockHeaderMap': blockHeaderMap
          .map((key, value) => MapEntry(key.toString(), value.toJson())),
      'receiveAddressBalanceMap': jsonEncode(receiveAddressBalanceMap
          .map((key, value) => MapEntry(key.toString(), value))),
      'changeAddressBalanceMap': jsonEncode(changeAddressBalanceMap
          .map((key, value) => MapEntry(key.toString(), value))),
      'receiveUsedIndexList': jsonEncode(receiveUsedIndexList),
      'changeUsedIndexList': jsonEncode(changeUsedIndexList),
      'receiveMaxGap': receiveMaxGap,
      'changeMaxGap': changeMaxGap,
      'initialReceiveIndex': initialReceiveIndex,
      'initialChangeIndex': initialChangeIndex,
    });
  }

  /// @nodoc
  factory WalletStatus.fromJson(String json) {
    Map<String, dynamic> jsonMap = jsonDecode(json);
    return WalletStatus(
        transactionList: List<Transaction>.from(
            jsonMap['transactionList'].map((e) => Transaction.fromJson(e))),
        utxoList:
            List<UTXO>.from(jsonMap['utxoList'].map((e) => UTXO.fromJson(e))),
        balance: Balance.fromJson(jsonMap['balance']),
        blockHeaderMap: jsonMap['blockHeaderMap'].map<int, BlockHeader>(
            (key, value) =>
                MapEntry(int.parse(key), BlockHeader.fromJson(value))),
        receiveAddressBalanceMap:
            jsonDecode(jsonMap['receiveAddressBalanceMap'])
                .map<int, int>((key, value) {
          return MapEntry(int.parse(key), value as int);
        }),
        changeAddressBalanceMap: jsonDecode(jsonMap['changeAddressBalanceMap'])
            .map<int, int>((key, value) {
          return MapEntry(int.parse(key), value as int);
        }),
        receiveUsedIndexList:
            jsonDecode(jsonMap['receiveUsedIndexList']).cast<int>(),
        changeUsedIndexList:
            jsonDecode(jsonMap['changeUsedIndexList']).cast<int>(),
        receiveMaxGap: jsonMap['receiveMaxGap'],
        changeMaxGap: jsonMap['changeMaxGap'],
        initialReceiveIndex: jsonMap['initialReceiveIndex'],
        initialChangeIndex: jsonMap['initialChangeIndex']);
  }

  /// Save the wallet on chain data to the file.
  void persist(int walletId) async {
    final db = FileDatabase('${walletId}_on_chain_data.json');
    // await db.save(walletId.toString(), toJson());
    await db.save(toJson());
  }

  /// Load the wallet on chain data from the file.
  static Future<WalletStatus> load(int walletId) async {
    final db = FileDatabase('${walletId}_on_chain_data.json');
    final jsonStr = await db.load();
    return WalletStatus.fromJson(jsonStr);
  }
}
