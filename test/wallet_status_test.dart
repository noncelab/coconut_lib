@Tags(['integration'])
import 'package:test/test.dart';
import 'package:coconut_lib/coconut_lib.dart';

void main() async {
  group('regtest test', () {
    late NodeConnector nodeConnector;
    late SingleSignatureVault vault;

    setUpAll(() async {
      BitcoinNetwork.setNetwork(BitcoinNetwork.regtest);
      nodeConnector = await NodeConnector.connectSync(
          'regtest-electrum.coconut.onl', 60401,
          ssl: true);

      // ignore: unused_local_variable
      Seed seedForApp = Seed.fromMnemonic(
          'thank split shrimp error own spirit slow glow act evidence globe slight');

      vault = SingleSignatureVault.fromSeed(seedForApp, AddressType.p2wpkh);
    });

    test('save test', () async {
      SingleSignatureWallet wallet =
          SingleSignatureWallet.fromDescriptor(vault.descriptor);
      await wallet.fetchOnChainData(nodeConnector);
      wallet.saveStatus();
    });
    test('load test', () async {
      // Fetch from the node
      SingleSignatureWallet walletFromNode =
          SingleSignatureWallet.fromDescriptor(vault.descriptor);
      await walletFromNode.fetchOnChainData(nodeConnector);

      // Fetch from the file
      SingleSignatureWallet walletFromFile =
          SingleSignatureWallet.fromDescriptor(vault.descriptor);

      await walletFromFile.loadStatus();

      // print(walletFromNode.getBalance());
      // print(walletFromFile.getBalance());

      // print(walletFromNode.walletOnChainData!.utxoList[0].derivationPath);
      // print(walletFromFile.walletOnChainData!.utxoList[0].derivationPath);

      // print(walletFromNode.walletOnChainData!.receiveUsedIndexList.toString());
      // print(walletFromFile.walletOnChainData!.receiveUsedIndexList.toString());

      expect(walletFromNode.getBalance(), walletFromFile.getBalance());
      expect(walletFromNode.walletStatus!.transactionList[0].transactionHash,
          walletFromFile.walletStatus!.transactionList[0].transactionHash);
      expect(walletFromNode.walletStatus!.utxoList[0].derivationPath,
          walletFromFile.walletStatus!.utxoList[0].derivationPath);
      expect(walletFromNode.walletStatus!.receiveUsedIndexList.toString(),
          walletFromFile.walletStatus!.receiveUsedIndexList.toString());
    });

    test('get address test', () async {
      SingleSignatureWallet wallet =
          SingleSignatureWallet.fromDescriptor(vault.descriptor);

      await wallet.loadStatus();

      int usedUntil = wallet.addressBook.usedReceive;
      int nextAddressIndex = wallet.getReceiveAddress().index;

      // print("used until : ${wallet.addressBook.usedReceive.toString()}");
      // print("max gap : ${wallet.walletOnChainData!.receiveMaxGap.toString()}");
      // print("${wallet.getReceiveAddress().derivationPath}");

      expect(usedUntil + 1, nextAddressIndex);

      // for (Address addr in wallet.addressBook.receiveList) {
      //   print(
      //       "${addr.address}, ${addr.index}, ${addr.derivationPath}, ${addr.isUsed}, ${addr.amount}");
      // }
    });
  });

  group('testnet test', () {
    late NodeConnector nodeConnector;
    BitcoinNetwork.setNetwork(BitcoinNetwork.testnet);
    Seed seed = Seed.fromMnemonic(
        'walk nose vibrant ankle advance frame violin apart summer depart volume squeeze decide visit manage tomorrow demand office minimum method manage arm dwarf cement',
        passphrase: 'ABC');
    SingleSignatureVault vault =
        SingleSignatureVault.fromSeed(seed, AddressType.p2wpkh);
    SingleSignatureWallet wallet =
        SingleSignatureWallet.fromDescriptor(vault.descriptor);

    setUpAll(() async {
      nodeConnector =
          await NodeConnector.connectSync('blockstream.info', 143, ssl: false);
    });

    test('testnet test', () async {
      await wallet.fetchOnChainData(nodeConnector);
      expect(wallet.addressBook.receiveList[1].isUsed, true);
    });
  });
}
