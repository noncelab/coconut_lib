@Tags(['unit'])
import 'dart:convert';
import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'node_connector_test.mocks.dart';

@GenerateMocks([ElectrumApi])
void main() async {
  var testData =
      jsonDecode(await File('test/wallet_test_data.json').readAsString());
  group('NodeConnector Tests', () {
    MockElectrumApi electrumApi = MockElectrumApi();
    NodeConnector nodeConnector = NodeConnector(electrumApi);

    setUp(() {
      when(electrumApi.connectionStatus)
          .thenReturn(SocketConnectionStatus.connected);
      when(electrumApi.broadcast(any)).thenAnswer((_) async {
        return Result.success(testData['transaction'][0]['hash']);
      });
      when(electrumApi.getTransaction(any)).thenAnswer((_) async {
        return Result.success('');
      });
    });

    test('broadcast successful', () async {
      var rawTransaction = testData['transaction'][0]['raw'];
      var result = await nodeConnector.broadcast(rawTransaction);

      expect(result.value!,
          '997ab8a3d0d425a925096fc925edd9b3e921a130ae2d5529a9ead6d7af404c1a');
    });
  });
}
