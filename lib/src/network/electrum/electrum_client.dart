part of '../../../coconut_lib.dart';

class ElectrumClient {
  // static final ElectrumClient _instance = ElectrumClient._();
  final int _timeout = 30;
  int _idCounter = 0;
  SocketManager _socketManager;
  Timer? _pingTimer;

  SocketConnectionStatus get connectionStatus =>
      _socketManager.connectionStatus;

  ElectrumClient._() : _socketManager = SocketManager();

  factory ElectrumClient({SocketManager? socketManager}) {
    ElectrumClient instance = ElectrumClient._();
    instance._socketManager = socketManager ?? SocketManager();
    instance._socketManager.onReconnect = instance._startPing;

    return instance;
  }

  Future<void> connect(String host, int port, {bool ssl = true}) async {
    await _socketManager.connect(host, port, ssl: ssl);

    _startPing();
  }

  void _startPing() {
    _pingTimer?.cancel(); // 기존 타이머가 있다면 취소
    _pingTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      if (connectionStatus != SocketConnectionStatus.connected) {
        timer.cancel();
      } else if (connectionStatus == SocketConnectionStatus.connected) {
        try {
          await ping();
        } catch (e) {
          print('Ping error: $e');
        }
      }
    });
  }

  String _scriptToReversedHash(String script) {
    String scriptHash = Hash.sha256fromHex(script);
    return hex.encode(hex.decode(scriptHash).reversed.toList());
  }

  Future<ElectrumResponse<T>> _call<T>(_ElectrumRequest request,
      ElectrumResponse<T> Function(dynamic json, {int? id}) fromJson) async {
    if (connectionStatus != SocketConnectionStatus.connected) {
      throw 'Can not connect to the server. Please connect and try again.';
    }
    final requestId = ++_idCounter;
    Map jsonRpcRequest = {
      'id': requestId,
      'jsonrpc': '2.0',
      'method': request.method,
      'params': request.params
    };
    // print('[${DateTime.now()}] - $jsonRpcRequest');
    await _socketManager.send(json.encode(jsonRpcRequest));

    final completer = Completer<Map>();
    _socketManager.setCompleter(requestId, completer);

    Map res = await completer.future.timeout(Duration(seconds: _timeout));

    if (res['error'] != null) {
      throw res['error'];
    }
    // print('[${DateTime.now()}] - $res');
    return fromJson(res['result'], id: requestId);
  }

  Future<String> ping() async {
    await _call(_PingReq(),
        (json, {int? id}) => ElectrumResponse(result: null, id: id));

    return 'pong';
  }

  Future<ServerFeaturesRes> serverFeatures() async {
    var response = await _call(
        _FeatureReq(),
        (json, {int? id}) =>
            ElectrumResponse(result: ServerFeaturesRes.fromJson(json), id: id));

    return response.result;
  }

  Future<List<String>> serverVersion() async {
    var response = await _call(
        _VersionReq(),
        (json, {int? id}) =>
            ElectrumResponse(result: List.castFrom<dynamic, String>(json)));

    return response.result;
  }

  Future<String> getBlockHeader(int height) async {
    var response = await _call(_BlockchainBlockHeaderReq(height),
        (json, {int? id}) => ElectrumResponse(result: json));

    return response.result;
  }

  Future<num> estimateFee(int targetConfirmation) async {
    var response = await _call(_BlockchainEstimateFeeReq(targetConfirmation),
        (json, {int? id}) => ElectrumResponse(result: json as num));

    return response.result;
  }

  Future<GetBalanceRes> getBalance(String script) async {
    var reversedScriptHash = _scriptToReversedHash(script);
    var response = await _call(
        _BlockchainScripthashGetBalanceReq(reversedScriptHash),
        (json, {int? id}) =>
            ElectrumResponse(result: GetBalanceRes.fromJson(json)));

    return response.result;
  }

  Future<List<GetHistoryRes>> getHistory(String script) async {
    var reversedScriptHash = _scriptToReversedHash(script);
    var response = await _call(
        _BlockchainScripthashGetHistoryReq(reversedScriptHash),
        (json, {int? id}) => ElectrumResponse(
            result: (json as List<dynamic>)
                .map((e) => GetHistoryRes.fromJson(e))
                .toList()));

    response.result.sort((prev, curr) => prev.height.compareTo(curr.height));

    return response.result;
  }

  Future<List<ListUnspentRes>> getUnspentList(String script) async {
    var reversedScriptHash = _scriptToReversedHash(script);
    var response = await _call(
        _BlockchainScripthashListUnspentReq(reversedScriptHash),
        (json, {int? id}) => ElectrumResponse(
            result: (json as List<dynamic>)
                .map((e) => ListUnspentRes.fromJson(e))
                .toList()));

    response.result.sort((prev, curr) => prev.height.compareTo(curr.height));

    return response.result;
  }

  Future<List<GetMempoolRes>> getMempool(String script) async {
    var reversedScriptHash = _scriptToReversedHash(script);
    var response = await _call(
        _BlockchainScripthashGetMempoolReq(reversedScriptHash),
        (json, {int? id}) => ElectrumResponse(
            result: (json as List<dynamic>)
                .map((e) => GetMempoolRes.fromJson(e))
                .toList()));

    return response.result;
  }

  Future<String> broadcast(String rawTransaction) async {
    var response = await _call(_BroadcastReq(rawTransaction),
        (json, {int? id}) => ElectrumResponse(result: json as String));

    return response.result;
  }

  Future<String> getTransaction(String txHash) async {
    var response = await _call(_BlockchainTransactionGetReq(txHash),
        (json, {int? id}) => ElectrumResponse(result: json as String));

    return response.result;
  }

  Future<List<List<num>>> getMempoolFeeHistogram() async {
    var response = await _call(_MempoolGetFeeHistogramReq(), (json, {int? id}) {
      if (json is List && json.isNotEmpty) {
        return ElectrumResponse(
            result: json.map((fee) {
          List<num> list = [];
          for (var e in fee) {
            if (e is num) list.add(e);
          }
          return list;
        }).toList());
      }
      List<List<num>> arr = [];
      return ElectrumResponse(result: arr);
    });
    return response.result;
  }

  Future<BlockHeaderSubscribe> getCurrentBlock() async {
    var response =
        await _call(_BlockchainHeadersSubscribeReq(), (json, {int? id}) {
      return ElectrumResponse(result: BlockHeaderSubscribe.fromJson(json));
    });

    return response.result;
  }

  Future<void> close() async {
    _pingTimer?.cancel();
    await _socketManager.disconnect();
  }
}
