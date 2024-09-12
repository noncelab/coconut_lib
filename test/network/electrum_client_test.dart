@Tags(['unit'])
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'electrum_client_test.mocks.dart';

@GenerateMocks([SocketManager])
void main() {
  late ElectrumClient electrumClient;
  late MockSocketManager mockSocketManager;

  setUpAll(() {
    mockSocketManager = MockSocketManager();
    electrumClient = ElectrumClient(socketManager: mockSocketManager);

    when(mockSocketManager.connect(any, any, ssl: anyNamed('ssl')))
        .thenAnswer((_) async {});
  });

  test('connect should call socketManager.connect', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);

    verify(mockSocketManager.connect('localhost', 50001, ssl: false)).called(1);
  });

  test('ping should return pong when connected', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);

    when(mockSocketManager.connectionStatus)
        .thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({'id': id, 'result': null});
    });
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'server.ping');
    });

    final response = await electrumClient.ping();

    expect(response, 'pong');
  });

  test('getBlockHeader should return block header', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus)
        .thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.block.header');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({'id': id, 'result': 'block header data'});
    });
    final response = await electrumClient.getBlockHeader(100);

    expect(response, 'block header data');
  });

  test('getBalance should return GetBalanceRes Object', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus)
        .thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.scripthash.get_balance');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': {'confirmed': 0, 'unconfirmed': 0}
      });
    });
    final response = await electrumClient.getBalance('0123456789abcdef');

    expect(response.confirmed, 0);
    expect(response.unconfirmed, 0);
  });

  test('getHistory should return GetHistoryRes List', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus)
        .thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.scripthash.get_history');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': [
          {'height': 1, 'tx_hash': 'txHash1'},
          {'height': 2, 'tx_hash': 'txHash2'}
        ]
      });
    });
    final response = await electrumClient.getHistory('0123456789abcdef');

    expect(response, isList);
    expect(response[0].height, 1);
    expect(response[0].txHash, 'txHash1');
    expect(response[1].height, 2);
    expect(response[1].txHash, 'txHash2');
  });
  test('getUnspentList should return ListUnspentRes List', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus)
        .thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.scripthash.listunspent');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': [
          {'height': 1, 'tx_hash': 'txHash1', 'tx_pos': 1, 'value': 1000},
          {'height': 2, 'tx_hash': 'txHash2', 'tx_pos': 0, 'value': 2000}
        ]
      });
    });
    final response = await electrumClient.getUnspentList('0123456789abcdef');

    expect(response, isList);
    expect(response[0].height, 1);
    expect(response[0].txHash, 'txHash1');
    expect(response[0].txPos, 1);
    expect(response[0].value, 1000);
    expect(response[1].height, 2);
    expect(response[1].txHash, 'txHash2');
    expect(response[1].txPos, 0);
    expect(response[1].value, 2000);
  });
  test('broadcast should return TransactionId String', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus)
        .thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.transaction.broadcast');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({'id': id, 'result': 'txIdString'});
    });
    final response = await electrumClient.broadcast('0123456789abcdef');

    expect(response.runtimeType, String);
    expect(response, 'txIdString');
  });
  test('getTransaction should return RawTransaction String', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus)
        .thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.transaction.get');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({'id': id, 'result': 'txIdString'});
    });
    final response = await electrumClient.getTransaction('0123456789abcdef');

    expect(response.runtimeType, String);
    expect(response, 'txIdString');
  });
  test('getMempoolFeeHistogram should return Num List', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus)
        .thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'mempool.get_fee_histogram');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': [
          [1, 1000],
          [2, 2000]
        ]
      });
    });
    final response = await electrumClient.getMempoolFeeHistogram();

    expect(response[0], [1, 1000]);
    expect(response[1], [2, 2000]);
  });

  test('getCurrentBlock should return BlockHeaderSubscribe Object', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus)
        .thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.headers.subscribe');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': {'height': 100, 'hex': '0123456789abcdef'}
      });
    });
    final response = await electrumClient.getCurrentBlock();

    expect(response.height, 100);
    expect(response.hex, '0123456789abcdef');
  });
}
