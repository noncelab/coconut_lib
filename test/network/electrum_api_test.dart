@Tags(['unit'])
import 'dart:convert';
import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_lib/src/network/electrum/electrum_response_types.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'electrum_api_test.mocks.dart';

@GenerateMocks([ElectrumClient])
void main() async {
  var testData =
      jsonDecode(await File('test/wallet_test_data.json').readAsString());

  group('ElectrumApi Tests', () {
    MockElectrumClient client = MockElectrumClient();
    when(client.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    ElectrumApi electrumApi =
        ElectrumApi('localhost', 1234, ssl: false, client: client);
    SingleSignatureWallet wallet = SingleSignatureWallet.fromDescriptor(
        testData['wallet'][0]['descriptor']);

    setUp(() {
      when(client.getTransaction(any)).thenAnswer((_) async => '');
      when(client.getHistory(any)).thenAnswer((_) async => []);
      when(client.getUnspentList(any)).thenAnswer((_) async => []);
      when(client.getCurrentBlock()).thenAnswer((_) async =>
          BlockHeaderSubscribe(height: 1000, hex: testData['block']['1000']));
    });

    test('broadcast successful', () async {
      when(client.broadcast(any)).thenAnswer((_) async => 'transaction_id');
      var result = await electrumApi.broadcast('raw_transaction');
      expect(result.isSuccess, true);
      expect(result.value, 'transaction_id');
    });

    test('broadcast failure', () async {
      when(client.broadcast(any)).thenThrow(Exception('Broadcast Error'));
      var result = await electrumApi.broadcast('invalid_transaction');
      expect(result.isFailure, true);
    });

    test('fullSync successful', () async {
      var result = await electrumApi.fullSync(wallet);

      expect(result.isSuccess, true);
    });

    test('fullSync failure', () async {
      when(client.getHistory(any)).thenThrow(Exception('Sync Error'));
      var result = await electrumApi.fullSync(wallet);
      expect(result.isFailure, true);
      expect(result.error!.errorCode, ErrorCodeEnum.unknownError);
    });

    test('getNetworkMinimumFeeRate no-mempool-tx', () async {
      when(client.getMempoolFeeHistogram()).thenAnswer((_) async => []);
      var result = await electrumApi.getNetworkMinimumFeeRate();
      expect(result.isSuccess, true);
      expect(result.value, 1);
    });

    test('getNetworkMinimumFeeRate', () async {
      when(client.getMempoolFeeHistogram()).thenAnswer((_) async => [
            [5, 1000],
            [3, 2000]
          ]);
      var result = await electrumApi.getNetworkMinimumFeeRate();
      expect(result.isSuccess, true);
      expect(result.value, 3);
    });

    test('getTransaction successful', () async {
      when(client.getTransaction(any))
          .thenAnswer((_) async => 'transaction_data');
      var result = await electrumApi.getTransaction('valid_tx_hash');
      expect(result.isSuccess, true);
      expect(result.value, 'transaction_data');
    });

    test('getTransaction failure', () async {
      when(client.getTransaction(any))
          .thenThrow(Exception('Transaction Error'));
      var result = await electrumApi.getTransaction('invalid_tx_hash');
      expect(result.isFailure, true);
    });
  });

  group('ElectrumApi fetch', () {});
}
