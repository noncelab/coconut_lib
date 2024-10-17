part of '../../../coconut_lib.dart';

/// @nodoc
class ElectrumApi extends Network {
  // static final ElectrumApi _instance = ElectrumApi._();

  final Map<int, BlockTimestamp> _blockMap = {};

  ElectrumClient _client;
  int _currentHeight = 0;
  DateTime? _lastUpdatedAt;

  @override
  get connectionStatus => _client.connectionStatus;

  @override
  int get reqId => _client._idCounter;

  @override
  BlockTimestamp get block =>
      _blockMap[_currentHeight] ?? BlockTimestamp(0, DateTime.now());

  ElectrumApi._() : _client = ElectrumClient();

  factory ElectrumApi(String host, int port,
      {bool ssl = true, ElectrumClient? client}) {
    ElectrumApi instance = ElectrumApi._();
    if (client != null) {
      instance._client = client;
    }

    if (instance._client.connectionStatus != SocketConnectionStatus.connected) {
      instance._client.connect(host, port, ssl: ssl);
    }

    return instance;
  }

  static Future<ElectrumApi> connectSync(String host, int port,
      {bool ssl = true}) async {
    var instance = ElectrumApi._();
    await instance._client.connect(host, port, ssl: ssl);

    return instance;
  }

  @override
  Future<Result<String, CoconutError>> broadcast(String rawTransaction) async {
    return _handleError(() => _client.broadcast(rawTransaction));
  }

  Future<Result<WalletStatus, CoconutError>> _sync(WalletBase wallet,
      {int initialReceiveIndex = 0, int initialChangeIndex = 0}) async {
    return _handleError(() async {
      List<Future> futures = [];
      List<UTXO> utxoEntityList = [];
      List<Transaction> txEntityList = [];
      Map<int, BlockHeader> blockEntityMap = {};
      Map<int, int> maxGapMap = {0: 0, 1: 0}; // 0: receive, 1: change
      Map<int, Map<int, int>> addressBalanceMap = {
        0: {},
        1: {}
      }; // 0: receive, 1: change, {index: amount}
      Map<int, List<int>> usedIndexList = {
        0: [],
        1: []
      }; // 0: receive, 1: change
      Set<int> toFetchBlockHeightSet = {};
      Balance balanceEntity = Balance(0, 0);

      // 트랜잭션 내역 조회
      Set<GetHistoryRes> txHistorySet = {};
      futures.add(fetchTxHistory(
        txHistorySet,
        wallet,
        false,
        maxGapMap,
        toFetchBlockHeightSet,
        initialIndex: initialReceiveIndex,
        usedIndexList,
      ));
      futures.add(fetchTxHistory(
        txHistorySet,
        wallet,
        true,
        maxGapMap,
        toFetchBlockHeightSet,
        usedIndexList,
        initialIndex: initialChangeIndex,
      ));

      // 트랜잭션 내역 조회 완료까지 대기, maxGapMap, toFetchBlockHeightSet 갱신됨
      await Future.wait(futures);

      // 필요한 블록 정보 조회
      await _fetchBlockEntity(toFetchBlockHeightSet, blockEntityMap);

      // 트랜잭션 로우 데이터 조회
      await _fetchRawTransaction(txEntityList, txHistorySet, blockEntityMap);

      // 트랜잭션 입력의 상세 트랜잭션 조회
      await _fetchTxInputsTxString(txEntityList);

      // 트랜잭션 내역 기준으로 AddressBook 세팅이 완료된 후 Utxo 조회로 주소별 잔액을 갱신함.
      await _pushNewUtxoList(wallet, utxoEntityList, balanceEntity,
          txEntityList, addressBalanceMap, maxGapMap);

      var walletStatus = WalletStatus(
        transactionList: txEntityList,
        utxoList: utxoEntityList,
        balance: balanceEntity,
        blockHeaderMap: blockEntityMap,
        receiveAddressBalanceMap: addressBalanceMap[0]!,
        changeAddressBalanceMap: addressBalanceMap[1]!,
        receiveUsedIndexList: usedIndexList[0]!,
        changeUsedIndexList: usedIndexList[1]!,
        receiveMaxGap: maxGapMap[0]!,
        changeMaxGap: maxGapMap[1]!,
      );

      return walletStatus;
    });
  }

  @override
  Future<Result<WalletStatus, CoconutError>> fullSync(WalletBase wallet) async {
    var syncResult = await _sync(wallet);
    if (syncResult.isFailure) {
      return Result.failure(syncResult.error!);
    }

    return Result.success(syncResult.value!);
  }

  @override
  Future<Result<int, CoconutError>> getNetworkMinimumFeeRate() {
    return _handleError(() async {
      List<List<num>> feeHistogram = await _client.getMempoolFeeHistogram();

      if (feeHistogram.isEmpty) {
        return 1;
      }

      num minimumFeeRate = feeHistogram.first.first;
      feeHistogram.map((feeInfo) => feeInfo.first).forEach((feeRate) {
        if (minimumFeeRate > feeRate) {
          minimumFeeRate = feeRate;
        }
      });

      return minimumFeeRate.ceil();
    });
  }

  @override
  void fetchBlock() {
    var now = DateTime.now();
    if (_lastUpdatedAt != null) {
      var lastUpdatedAt = _lastUpdatedAt!.add(Duration(seconds: 10));
      if (now.isBefore(lastUpdatedAt)) {
        return;
      }
    }
    getCurrentBlock().then((block) {
      _currentHeight = block.height;
      _lastUpdatedAt = now;
      _blockMap[_currentHeight] = BlockTimestamp(
          _currentHeight,
          DateTime.fromMillisecondsSinceEpoch(block.timestamp * 1000,
              isUtc: true));
    });
  }

  @override
  Future<BlockTimestamp> fetchBlockSync() async {
    var now = DateTime.now();
    if (_lastUpdatedAt != null) {
      var lastUpdatedAt = _lastUpdatedAt!.add(Duration(seconds: 10));
      if (now.isBefore(lastUpdatedAt)) {
        return _blockMap[_currentHeight]!;
      }
    }
    var blockEntity = await getCurrentBlock();
    _currentHeight = blockEntity.height;
    _lastUpdatedAt = now;
    var block = BlockTimestamp(
        _currentHeight,
        DateTime.fromMillisecondsSinceEpoch(blockEntity.timestamp * 1000,
            isUtc: true));
    _blockMap[_currentHeight] = block;

    return block;
  }

  Future<BlockHeader> getCurrentBlock() async {
    var result = await _client.getCurrentBlock();
    return BlockHeader.parse(result.height, result.hex);
  }

  /// utxo 조회는 balance 조회를 동시에 진행하여 0번 인덱스부터 조회하도록 고정
  Future<void> _pushNewUtxoList(
      WalletBase wallet,
      List<UTXO> utxoEntityList,
      Balance balanceEntity,
      List<Transaction> txEntityList,
      Map<int, Map<int, int>> addressBalanceMap,
      Map<int, int> maxGapMap) async {
    await _pushUnspentList(wallet, utxoEntityList, balanceEntity, txEntityList,
        addressBalanceMap, maxGapMap[0]!,
        isChange: false);
    await _pushUnspentList(wallet, utxoEntityList, balanceEntity, txEntityList,
        addressBalanceMap, maxGapMap[1]!,
        isChange: true);
  }

  Future<void> _pushUnspentList(
      WalletBase wallet,
      List<UTXO> utxoList,
      Balance balanceEntity,
      List<Transaction> txEntityList,
      Map<int, Map<int, int>> addressBalanceMap,
      int maxGap,
      {bool isChange = false}) async {
    int gapIndex = 0 + maxGap;
    int changeIndex = isChange ? 1 : 0;
    List<Future<void>> futureList = [];

    for (int index = 0; index < gapIndex; ++index) {
      final address = wallet.getAddress(index, isChange: isChange);
      // script pubkey 에 앞 2글자는 길이 바이트가 포함되어 제외함.
      final script = ScriptPublicKey.p2wpkh(address).serialize().substring(2);
      final derivationPath =
          '${wallet.derivationPath}/${isChange ? 1 : 0}/$index';

      var future = _client.getUnspentList(script);

      future.then((unspentList) {
        if (unspentList.isEmpty) {
          return;
        }

        var amount = _sumUnspentAmount(unspentList);
        addressBalanceMap[changeIndex]![index] = amount;

        for (var unspent in unspentList) {
          var transactionEntity = txEntityList.firstWhere(
              (txEntity) => txEntity.transactionHash == unspent.txHash);
          // var utxo = UTXO.fromApiResponse(
          //     walletId: walletId,
          //     res: unspent,
          //     txString: transactionEntity.serialize(),
          //     derivationPath: derivationPath,
          //     timestamp: transactionEntity.timestamp ?? 0);
          var utxo = UTXO(unspent.txHash, unspent.txPos, unspent.value,
              derivationPath, transactionEntity.timestamp, unspent.height);

          utxoList.add(utxo);

          if (unspent.height == 0) {
            balanceEntity.unconfirmed += unspent.value;
          } else {
            balanceEntity.confirmed += unspent.value;
          }
        }
      });
      futureList.add(future);
    }
    await Future.wait(futureList);
  }

  int _sumUnspentAmount(List<ListUnspentRes> unspentList) =>
      unspentList.map((unspent) => unspent.value).reduce((a, b) => a + b);

  @override
  Future<Result<String, CoconutError>> getTransaction(String txHash) async {
    return _handleError(() {
      return _getTransaction(txHash);
    });
  }

  Future<String> _getTransaction(String txHash) async {
    return _client.getTransaction(txHash);
  }

  Future<void> _fetchRawTransaction(
    List<Transaction> txEntityList,
    Set<GetHistoryRes> txHistorySet,
    Map<int, BlockHeader> blockEntityMap,
  ) async {
    // 트랜잭션 상세 조회
    Map<String, Transaction> fetchedTxEntityMap = {};
    List<Future> futures = [];

    for (var txHistory in txHistorySet) {
      var future = _getTransaction(txHistory.txHash);

      future.then((txString) {
        int timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
        int blockHeight = txHistory.height <= 0 ? 0 : txHistory.height;
        if (blockHeight > 0) {
          timestamp = blockEntityMap[blockHeight]!.timestamp;
        }

        var txEntity = Transaction.fromOnChainData(
            txString, timestamp, blockHeight, [], '');

        // var txEntity = TransactionEntity.from(wallet.identifier, txString, [],
        //     height: blockHeight, timestamp: timestamp);

        fetchedTxEntityMap[txHistory.txHash] = txEntity;
      });

      futures.add(future);
    }
    await Future.wait(futures);

    txEntityList.addAll(fetchedTxEntityMap.values);
  }

  bool _isCoinbaseTransaction(Transaction tx) {
    if (tx.inputs.isEmpty) {
      return false;
    }

    if (tx.inputs.length > 1) {
      return false;
    }

    if (tx.inputs[0].transactionHash !=
        '0000000000000000000000000000000000000000000000000000000000000000') {
      return false;
    }

    return Converter.decToHex(tx.inputs[0].index) == 'ffffffff';
  }

  Future<void> _fetchTxInputsTxString(
      Iterable<Transaction> txEntityList) async {
    for (var txEntity in txEntityList) {
      List<Future<String>> futures = [];

      if (_isCoinbaseTransaction(txEntity)) {
        continue;
      }

      for (var i = 0; i < txEntity.inputs.length; ++i) {
        var input = txEntity.inputs[i];
        futures.add(_getTransaction(input.transactionHash));
      }

      List<String> results = await Future.wait(futures);

      for (var i = 0; i < results.length; ++i) {
        txEntity.perviousTransactionList.add(Transaction.parse(results[i]));
      }
    }
  }

  Future<void> fetchTxHistory(
      Set<GetHistoryRes> txHistorySet,
      WalletBase wallet,
      bool isChange,
      Map<int, int> maxGapMap,
      Set<int> toFetchBlockHeightSet,
      Map<int, List<int>> usedIndexList,
      {int initialIndex = 0}) async {
    int gapIndex = initialIndex + gapLimit;
    int index = initialIndex;
    int mapIndex = isChange ? 1 : 0;
    // input/output 에 본인의 script가 여러개 사용될 경우에 대비하여 txHash 기준으로 트랜잭션을 저장하는 용도
    List<Future> futures = [];

    while (true) {
      futures = [];
      for (int i = index; i < gapIndex; i++) {
        var address = wallet.getAddress(i, isChange: isChange);

        // script pubkey 에 앞 2글자는 길이 바이트가 포함되어 제외함.
        String script;
        if (wallet.addressType == AddressType.p2wpkh) {
          script = ScriptPublicKey.p2wpkh(address).serialize();
        } else if (wallet.addressType == AddressType.p2wsh) {
          script = ScriptPublicKey.p2wsh(address).serialize();
        } else if (wallet.addressType == AddressType.p2pkh) {
          script = ScriptPublicKey.p2pkh(address).serialize();
        } else if (wallet.addressType == AddressType.p2sh) {
          script = ScriptPublicKey.p2sh(address).serialize();
        } else {
          throw Exception('Unsupported address type');
        }

        var scriptWithoutSize = script.substring(2);
        var future = _client.getHistory(scriptWithoutSize);

        future.then((historyList) {
          var callBackIndex = i;
          if (historyList.isNotEmpty) {
            toFetchBlockHeightSet.addAll(historyList
                .where((history) => history.height > 0)
                .map((history) => history.height));
            usedIndexList[mapIndex]!.add(callBackIndex);
            txHistorySet.addAll(historyList);
            int newGap = i + gapLimit;
            if (gapIndex < newGap) {
              gapIndex = newGap;
            }
          }
        });

        futures.add(future);
        ++index;
      }

      // 모든 비동기 함수가 완료될 때까지 기다립니다.
      await Future.wait(futures);

      // newGap이 갱신되지 않았다면 반복을 종료합니다.
      if (index >= gapIndex) {
        maxGapMap[mapIndex] = gapIndex;
        break;
      }
    }
  }

  Future<Result<T, CoconutError>> _handleError<T>(
      Future<T> Function() clientOperation) async {
    try {
      return Result.success(await clientOperation());
    } catch (e, stackTrace) {
      print(e);
      print(stackTrace);
      CoconutError coconutError;
      if (e is Map<String, dynamic>) {
        if ((e['message'] as String).contains('Fee exceeds')) {
          coconutError = CoconutError(
              ErrorCodeEnum.exceededFee, '수수료가 너무 높습니다. 수수료를 낮춰서 다시 시도해 주세요.');
        } else {
          coconutError =
              CoconutError(ErrorCodeEnum.electrumRpcError, '오류가 발생했습니다.');
        }
      } else if (e is String) {
        coconutError = CoconutError(ErrorCodeEnum.electrumRpcError, e);
      } else {
        coconutError = CoconutError.unknown(error: e);
      }
      return Result.failure(coconutError);
    }
  }

  Future<void> _fetchBlockEntity(
      Set<int> heightSet, Map<int, BlockHeader> blockEntityMap) async {
    List<Future> futures = [];
    var list = heightSet.toList();

    list.sort();

    for (int height in list) {
      var future = _client.getBlockHeader(height);

      future.then((header) {
        var entity = BlockHeader.parse(height, header);
        blockEntityMap[height] = entity;
      });

      futures.add(future);
    }
    await Future.wait(futures);
  }

  Future<void> close() async {
    await _client.close();
  }
}
