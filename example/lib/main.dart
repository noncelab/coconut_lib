import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';

void main() async {
  print("0. Set the Bitcoin Network");
  Repository.initialize('DB_Scenario');
  BitcoinNetwork.setNetwork(BitcoinNetwork.regtest);
  NodeConnector nodeConnector = await NodeConnector.connectSync(
      'regtest-electrum.coconut.onl', 60401,
      ssl: true);

  print("1. Create a vault");
  // ignore: unused_local_variable
  Seed seedForUnitTest = Seed.fromMnemonic(
      'walk nose vibrant ankle advance frame violin apart summer depart volume squeeze decide visit manage tomorrow demand office minimum method manage arm dwarf cement',
      passphrase: 'ABC');

  // ignore: unused_local_variable
  Seed emptySeed = Seed.fromMnemonic(
      'cross february involve argue travel crush they soul echo type tonight strike head carpet joke',
      passphrase: 'ABC');

  // ignore: unused_local_variable
  Seed seedForApp = Seed.fromMnemonic(
      'thank split shrimp error own spirit slow glow act evidence globe slight');

  SingleSignatureVault vault =
      SingleSignatureVault.fromSeed(seedForApp, AddressType.p2wpkh);
  print(' - Mnemonic: ${vault.keyStore.seed.mnemonic}');

  print("2. Sync to the wallet");
  // Repository.initialize('Coconut_Wallet');
  SingleSignatureWallet wallet =
      SingleSignatureWallet.fromDescriptor(vault.descriptor);
  print(
      ' - Extended Public Key: ${wallet.keyStore.extendedPublicKey.serialize()}');
  print(' - Devation Path: ${wallet.derivationPath}');
  print(' - Fingerprint: ${wallet.keyStore.fingerprint}');

  var syncResult = await nodeConnector.fetch(wallet);
  if (syncResult.isFailure) {
    throw Exception(" - Sync failed : ${syncResult.error}");
  } else {
    print(' - Transaction Sync Success');
    await Repository().sync(wallet, syncResult.value!);
  }

  print(' - [CurrentBlock] height: ${nodeConnector.currentBlock.height}'
      ' timestamp: ${nodeConnector.currentBlock.timestamp}');

  print(' - Sync Address Book');
  print(' - Balance: ${wallet.getBalance()}');

  print('3. Receive a Bitcoin');
  print(' - Address: ${wallet.getReceiveAddress()}');
  print(' - Utxo List : ');
  for (UTXO utxo in wallet.getUtxoList()) {
    print('   ${utxo.transactionHash}:[${utxo.index}] ${utxo.amount}');
  }
  print(' - Transfer History : ');
  for (Transfer transfer in wallet.getTransferList(cursor: 0, count: 10)) {
    print(
        '   [${transfer.transferType}:${transfer.timestamp}] ${transfer.transactionHash} : ${transfer.amount}');
  }
  print(' - Total Amount : ${wallet.getBalance()}');
  print(' - Total Unconfirmed Amount : ${wallet.getUnconfirmedBalance()}');

  print(' - Address and amount :');
  List<Address> receiveList = wallet.addressBook.receiveBook.values.toList();
  receiveList.sort((prev, curr) => prev.index.compareTo(curr.index));
  // changeList.sort((prev, curr) => prev.index.compareTo(curr.index));
  for (Address address in receiveList) {
    print(
        '   ${address.address}, path : ${address.derivationPath}, is Used? : ${address.isUsed}, amount : ${address.amount}');
  }

  print('4. Create a PSBT (in wallet)');
  String receiverAddress = wallet.getReceiveAddress().address;
  // String receiverAddress = 'tb1q8vn76dcysgxany6mlkgz0jd80d7pl9mzhqee73';
  int sendingAmount = 1000;
  int feeRate = 14;
  print(
      " - Fee estimation : ${await wallet.estimateFee(receiverAddress, sendingAmount, feeRate)}");
  String psbt =
      await wallet.generatePsbt(receiverAddress, sendingAmount, feeRate);
  // if you want to send all Bitcoin : String psbt = wallet.generatePsbtWithMaximum(receiverAddress, 10);
  print(" - Generated PSBT : $psbt");
  print(
      " - Validate address : ${WalletUtility.validateAddress(receiverAddress)}}");

  print('6. Receive PSBT in the wallet (in vault)');
  PSBT vaultReceivedPsbt = PSBT.parse(psbt);
  print(
      ' - check fingerprint : ${vaultReceivedPsbt.derivationPath?.parentFingerprint}');
  print(" - Sending amount : ${vaultReceivedPsbt.sendingAmount}");
  print(" - Fee : ${vaultReceivedPsbt.fee}");

  print('7. sign the transaction (in vault)');
  String signedPsbt = vault.addSignatureToPsbt(psbt);

  print(" - Signed PSBT : $signedPsbt");

  print('7. Receive signed PSBT (in wallet)');
  PSBT walletReceivedPsbt = PSBT.parse(signedPsbt);
  Transaction signed =
      walletReceivedPsbt.getSignedTransaction(wallet.addressType);
  print(' - final Transaction : ${signed.serialize()}');

  print('8. Broadcast the transaction');
  print(
      ' - Unsigned Tx ID : ${walletReceivedPsbt.unsignedTransaction!.transactionHash}');
  print(' - Transaction ID : ${signed.transactionHash}');
  print(' - Transaction : ${signed.serialize()}');
  // Result result = await nodeConnector.broadcast(signed.serialize());
  // print(' - Transaction is broadcasted: ${result.value}');

  exit(0);
}
