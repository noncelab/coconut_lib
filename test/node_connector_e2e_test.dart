@Tags(['integration'])
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

Future<void> main() async {
  group('NodeConnector', () {
    test('generate exceeded feerate tx', () async {
      BitcoinNetwork.setNetwork(BitcoinNetwork.regtest);
      NodeConnector nodeConnector = await NodeConnector.connectSync(
          'regtest-electrum.coconut.onl', 60401);
      SingleSignatureVault vault = SingleSignatureVault.fromMnemonic(
          'treat auto inmate dismiss erode twist stick olympic light patch piece delay',
          AddressType.p2wpkh);
      SingleSignatureWallet wallet =
          SingleSignatureWallet.fromDescriptor(vault.descriptor);

      await wallet.fetchOnChainData(nodeConnector);
      // await Repository().sync(wallet, syncResult.value!);

      var address = wallet.getReceiveAddress();
      var estimateFee = await wallet.estimateFee(address.address, 547, 100000);

      print(estimateFee);

      var psbt = await wallet.generatePsbt(address.address, 547, 100000);

      var signedPsbt = vault.addSignatureToPsbt(psbt);

      var transaction =
          PSBT.parse(signedPsbt).getSignedTransaction(AddressType.p2wpkh);

      var result = await nodeConnector.broadcast(transaction.serialize());

      expect(result.error?.errorCode, ErrorCodeEnum.exceededFee);
    });

    test('generate small utxo', () async {
      BitcoinNetwork.setNetwork(BitcoinNetwork.regtest);
      NodeConnector nodeConnector = await NodeConnector.connectSync(
          'regtest-electrum.coconut.onl', 60401);
      SingleSignatureVault vault = SingleSignatureVault.fromMnemonic(
          'treat auto inmate dismiss erode twist stick olympic light patch piece delay',
          AddressType.p2wpkh);
      SingleSignatureWallet wallet =
          SingleSignatureWallet.fromDescriptor(vault.descriptor);

      await wallet.fetchOnChainData(nodeConnector);

      var address = wallet.getReceiveAddress();

      var psbt = await wallet.generatePsbt(address.address, 547, 1);

      var signedPsbt = vault.addSignatureToPsbt(psbt);

      var transaction =
          PSBT.parse(signedPsbt).getSignedTransaction(AddressType.p2wpkh);

      var result = await nodeConnector.broadcast(transaction.serialize());

      expect(result.value, isNotNull);
    });

    test('max amount tx', () async {
      BitcoinNetwork.setNetwork(BitcoinNetwork.regtest);
      NodeConnector nodeConnector = await NodeConnector.connectSync(
          'regtest-electrum.coconut.onl', 60401);
      SingleSignatureVault vault = SingleSignatureVault.fromMnemonic(
          'treat auto inmate dismiss erode twist stick olympic light patch piece delay',
          AddressType.p2wpkh);
      SingleSignatureWallet wallet =
          SingleSignatureWallet.fromDescriptor(vault.descriptor);

      await wallet.fetchOnChainData(nodeConnector);
      // await Repository().sync(wallet, syncResult.value!);

      var address = wallet.getReceiveAddress();

      var psbt = await wallet.generatePsbtWithMaximum(address.address, 1);
      var estimateFee = await wallet.estimateFeeWithMaximum(address.address, 1);

      print('before psbt: $psbt');
      print('estimateFee: $estimateFee');

      var signedPsbt = vault.addSignatureToPsbt(psbt);

      print('after psbt: $signedPsbt');

      var transaction =
          PSBT.parse(signedPsbt).getSignedTransaction(AddressType.p2wpkh);

      print('transaction: ${transaction.serialize()}');
      var totalOutput = transaction.outputs
          .map((output) => output.amount)
          .reduce((a, b) => a + b);
      print('totalOutput: $totalOutput');
      print('totalInput: ${wallet.getBalance()}');
      print('transaction.calculateFee(1): ${transaction.calculateFee(1)}');
      print('transaction.estimateFee(1): ${transaction.estimateFee(1)}');

      var result = await nodeConnector.broadcast(transaction.serialize());

      expect(result.error?.errorCode, ErrorCodeEnum.exceededFee);
    });
  }, tags: 'exclude');
}
