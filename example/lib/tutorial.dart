import 'dart:io';
import 'package:coconut_lib/coconut_lib.dart';

void main() async {
  /*
  This shows the process from creating a Bitcoin wallet in the Coconut Library to sending Bitcoin.
  Please check that the roles of the Vault and the Wallet are separate.
  Enjoy Bitcoin programming with Coconut Library!
  */

  /// >> In Vault
  /// choose the Bitcoin Network
  // BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
  // BitcoinNetwork.setNetwork(BitcoinNetwork.testnet);
  BitcoinNetwork.setNetwork(BitcoinNetwork.regtest);

  /// generate air-gapped vault
  /// random vault
  // SingleSignatureVault randomMnemonicVault =
  //     SingleSignatureVault.random(AddressType.p2wpkh);
  // print("Generated Mnemonic : ${randomMnemonicVault.keyStore.seed.mnemonic}");

  /// mnemonic vault
  SingleSignatureVault mnemonicVault = SingleSignatureVault.fromMnemonic(
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      AddressType.p2wpkh,
      passphrase: 'ABC');

  // >> In Wallet
  /// import expub to watch-only wallet with descriptor(BIP-0380)
  SingleSignatureWallet watchOnlyWallet =
      SingleSignatureWallet.fromDescriptor(mnemonicVault.descriptor);

  /// Obtain the bitcoin from faucet
  print("address : ${watchOnlyWallet.getAddress(0)}");

  /// connect to the node and fetch transaction data
  Repository.initialize('Coconut_Tutorial'); // db for tx history
  NodeConnector nodeConnector = await NodeConnector.connectSync(
      'regtest-electrum.coconut.onl', 60401,
      ssl: true); // node connection
  var syncResult = await nodeConnector.fetch(watchOnlyWallet); // fetch tx data
  if (syncResult.isFailure) {
    throw Exception(" - Sync failed : ${syncResult.error}");
  } else {
    print(' - Transaction Sync Success');
    await Repository()
        .sync(watchOnlyWallet, syncResult.value!); // save tx data into db
  }

  /// and then, check the balance
  print("balance : ${watchOnlyWallet.getBalance()}");

  /// create a PSBT(BIP-0174) to my another address
  PSBT unsignedPSBT = PSBT.forSending(
      "bcrt1qyyl6eld8zq0zgh5jf8u5n3lv4jz9tjzeny2lq9", 1000, 3, watchOnlyWallet);

  /// >> In Vault
  /// vault can sign the PSBT
  String signedPsbt =
      mnemonicVault.addSignatureToPsbt(unsignedPSBT.serialize());

  /// >> In Wallet
  // watchOnlyWallet can broadcast the signed transaction
  PSBT signedPSBT =
      PSBT.parse(signedPsbt); // parse the PSBT received from vault
  Transaction completedTx = signedPSBT
      .getSignedTransaction(watchOnlyWallet.addressType); // transaction object
  Result result =
      await nodeConnector.broadcast(completedTx.serialize()); // broadcast
  print(' - Transaction is broadcasted: ${result.value}');

  /// need to sync again
  var finalSyncResult =
      await nodeConnector.fetch(watchOnlyWallet); // fetch tx data
  if (syncResult.isFailure) {
    throw Exception(" - Sync failed : ${finalSyncResult.error}");
  } else {
    print(' - Transaction Sync Success');
    await Repository()
        .sync(watchOnlyWallet, finalSyncResult.value!); // save tx data into db
  }

  /// check the balance again
  print("balance : ${watchOnlyWallet.getBalance()}");

  exit(0);
}
