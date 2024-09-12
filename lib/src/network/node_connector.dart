part of '../../coconut_lib.dart';

class IsolateConnectorData {
  final SendPort? _sendPort;
  final String _host;
  final int _port;
  final bool _ssl;

  SendPort? get sendPort => _sendPort;

  String get host => _host;

  int get port => _port;

  bool get ssl => _ssl;

  IsolateConnectorData(this._sendPort, this._host, this._port, this._ssl);
}

class NodeConnector {
  // static NodeConnector? _singleton;
  Network _network;
  Completer<void>? _syncCompleter;
  late String _host;
  late int _port;
  late bool _ssl;
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  late Completer<void> _isolateReady;

  NodeConnector(this._network) {
    _isolateReady = Completer<void>();
  }

  NodeConnector._() : _network = ElectrumApi._() {
    _isolateReady = Completer<void>();
  }

  int get networkReqId => _network.reqId;

  bool get isSyncing => _syncCompleter != null;

  SocketConnectionStatus get connectionStatus => _network.connectionStatus;

  Block get currentBlock {
    _network.fetchBlock();
    return _network.block;
  }

  Future<void> _initializeIsolate() async {
    try {
      _receivePort = ReceivePort();
      var data =
          IsolateConnectorData(_receivePort?.sendPort, _host, _port, _ssl);
      _isolate = await Isolate.spawn(_isolateEntry, data);
      _receivePort?.listen((message) {
        if (message is SendPort) {
          _sendPort = message;
          _isolateReady.complete();
        }
      }, onError: (error) {
        print('Error in ReceivePort: $error');
        throw error;
      });
    } catch (e) {
      print('Initialization error: $e');
      _isolateReady.completeError(e);
    }
  }

  static void _isolateEntry(IsolateConnectorData data) async {
    final port = ReceivePort();
    data.sendPort?.send(port.sendPort);

    port.listen((message) async {
      if (message is List && message.length == 2) {
        WalletBase wallet = message[0];
        SendPort replyPort = message[1];

        late ElectrumApi electrumApi;
        try {
          electrumApi = await ElectrumApi.connectSync(data.host, data.port,
              ssl: data.ssl);
          var syncResult = await electrumApi.fullSync(wallet);
          replyPort.send(syncResult);
        } catch (e) {
          print('Error in isolate processing: $e');
          replyPort.send(Result.failure(CoconutError(
              ErrorCodeEnum.unknownError, 'Error in isolate processing')));
        } finally {
          electrumApi.close();
        }
      }
    }, onError: (error) {
      print('Error in isolate ReceivePort: $error');
    });
  }

  static Future<NodeConnector> connectSync(String host, int port,
      {ConnectionTypeEnum connectionType = ConnectionTypeEnum.electrum,
      bool ssl = true,
      Network? network}) async {
    // if (_singleton == null) {
    //   _singleton = NodeConnector._();
    // }
    NodeConnector nodeConnector = NodeConnector._();

    nodeConnector._host = host;
    nodeConnector._port = port;
    nodeConnector._ssl = ssl;
    nodeConnector._network =
        network ?? await ElectrumApi.connectSync(host, port, ssl: ssl);
    await nodeConnector._network.fetchBlockSync();
    await nodeConnector._initializeIsolate();
    await nodeConnector._isolateReady.future; // SendPort가 설정될 때까지 대기
    return nodeConnector;
  }

  Future<Result<String, CoconutError>> broadcast(String rawTransaction) async {
    return _network.broadcast(rawTransaction).then((result) async {
      // broadcast 에 성공했을 경우에만 objectbox에 저장
      if (result.isFailure) {
        return result;
      }

      return result;
    });
  }

  Future<Result<WalletFetchResult, CoconutError>> fetch(
      WalletBase wallet) async {
    if (_syncCompleter != null) {
      // 이미 동기화 중이면, 즉시 실패 반환
      return Future.value(Result.failure(
          CoconutError(ErrorCodeEnum.alreadySyncing, 'Already syncing.')));
    }
    _syncCompleter = Completer<void>();

    try {
      if (connectionStatus != SocketConnectionStatus.connected) {
        return Result.failure(CoconutError(ErrorCodeEnum.electrumRpcError,
            'The RPC server is not connected.'));
      }

      await _isolateReady.future; // SendPort가 설정될 때까지 대기

      if (_sendPort == null) {
        throw Exception('Isolate not initialized');
      }

      final responsePort = ReceivePort();
      _sendPort!.send([wallet, responsePort.sendPort]);

      var result = await responsePort.first;
      if (result is Result<WalletFetchResult, CoconutError>) {
        return result;
      } else {
        responsePort.close();
        return Result.failure(
            CoconutError(ErrorCodeEnum.unknownError, 'Unknown response type'));
      }
    } finally {
      _syncCompleter?.complete();
      _syncCompleter = null;
    }
  }

  Future<Result<int, CoconutError>> getNetworkMinimumFeeRate() async {
    return _network.getNetworkMinimumFeeRate();
  }

  void stopFetching() {
    // fetch 작업 중지 및 자원 해제
    if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
      _syncCompleter?.completeError(CoconutError(
          ErrorCodeEnum.networkDisconnected, 'Network disconnected.'));
    }
    dispose();
  }

  void dispose() {
    _syncCompleter = null;
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    // _singleton = null;
  }
}
