@Tags(['integration'])
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

Future<void> main() async {
  ElectrumClient client = ElectrumClient();
  await client.connect('regtest-electrum.coconut.onl', 60401, ssl: true);

  test('ping', () async {
    var result = await client.ping();

    expect(result, 'pong');
  });

  test('server.version', () async {
    /// param: ["electrs/0.10.5", ["1.1", "1.4"]]
    var result = await client.serverVersion();

    expect(result.contains('1.4'), isTrue);
  });

  test('blockchain.block.header', () async {
    var blockHeaderString = '0000002006226e46111a0b59caaf126043eb5bbf28c34f3a5e'
        '332a1fc7b2b73cf188910fdaada1a0c352b172709f0dbed7460a3a0c2769c62f76dc0b'
        '2e98febee29b6f6566697a66ffff7f2000000000';
    var result = await client.getBlockHeader(1);

    expect(result.runtimeType, String);
    expect(result, blockHeaderString);
  });

  test('blockchain.estimatefee', () async {
    /// 0.012229100000000001
    var result = await client.estimateFee(1);

    expect(result.runtimeType, num);
    expect(result, greaterThan(0));
  });

  test('blockchain.scripthash.get_balance', () async {
    /// {confirmed: 5000010000, unconfirmed: 0}
    var script = '0014b6bcdbde3832fe660d371c31775c887ea93c0d2f';
    var result = await client.getBalance(script);

    expect(result.confirmed + result.unconfirmed, greaterThan(0));
  });

  test('blockchain.scripthash.get_history', () async {
    var script =
        '4104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac';
    var result = await client.getHistory(script);

    expect(result, isList);
    expect(result.first.height, 0);
    expect(result.first.txHash,
        '4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b');
  });

  test('blockchain.scripthash.listunspent', () async {
    var script =
        '4104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac';
    var result = await client.getUnspentList(script);

    expect(result.first.height, 0);
    expect(result.first.txHash,
        '4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b');
    expect(result.first.value, 5000000000);
    expect(result.first.txPos, 0);
  });

  test('blockchain.scripthash.get_mempool', () async {
    var script = '0014991e127fe706494844e4432c224b6a9f015b85fb';
    var result = await client.getMempool(script);

    expect(result.first.txHash, '');
  }, skip: 'Requires a script that exists in the actual mempool.');

  test('blockchain.transaction.broadcast', () async {
    var rawTransaction =
        '02000000000101b9852d317b08716d0f7db93bee16bab85660999e257e6d872730517332a01de701000000000100000002df060000000000001600143b27ed3704820dd9935bfd9027c9a77b7c1f9762b80b000000000000160014e1c691c1207b0a316f4bd11af39764c29fef5e4d02473044022005e531ba0225f8df4ea2936be1aaab9ac6816d01a974d0b0ab204daf8f9a92c10220128adf146a66c59a434a9c7e5252e9c66e2e40f258f9c49d13138a41acaf72be01210246c18ea7c5624b87e5f65a60842c9a22b27ae7e3630a95abeb3545525976182400000000';
    var result = await client.broadcast(rawTransaction);

    expect(result, isNotEmpty);
    // });
  }, skip: 'Requires a raw transaction (hexadecimal) to actually broadcast.');

  test('blockchain.transaction.get', () async {
    var txHash =
        '656f9be2befe982e0bdc762fc669270c3a0a46d7be0d9f7072b152c3a0a1adda';
    var result = await client.getTransaction(txHash);

    expect(result, isNotEmpty);
  });

  test('mempool.get_fee_histogram', () async {
    var result = await client.getMempoolFeeHistogram();

    for (var fee in result) {
      print('$fee / ${fee.runtimeType}');
      for (var e in fee) {
        print('  $e / ${e.runtimeType}');
      }
    }
    expect(result, isList);
  });

  test('blockchain.headers.subscribe', () async {
    var result = await client.getCurrentBlock();

    expect(result.height, greaterThan(0));
    expect(result.hex.runtimeType, String);
    expect(result.hex, isNotEmpty);
  });
}
