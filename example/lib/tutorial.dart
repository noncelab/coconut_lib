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
  BitcoinNetwork.setNetwork(BitcoinNetwork.regtest);

  /// generate air-gapped vault
  SingleSignatureVault mnemonicVault = SingleSignatureVault.fromMnemonic(
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      AddressType.p2wpkh,
      passphrase: 'ABC');

  // >> In Wallet
  /// import expub to watch-only wallet with descriptor(BIP-0380)
  SingleSignatureWallet watchOnlyWallet =
      SingleSignatureWallet.fromDescriptor(mnemonicVault.descriptor);

  /// Obtain the bitcoin from faucet
  print("address : ${watchOnlyWallet.getReceiveAddress()}");

  /// connect to the node and fetch transaction data
  NodeConnector nodeConnector = await NodeConnector.connectSync(
      'regtest-electrum.coconut.onl', 60401,
      ssl: true);

  /// fetch on chain data
  await watchOnlyWallet.fetchOnChainData(nodeConnector);

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
  Transaction signedTx = signedPSBT
      .getSignedTransaction(watchOnlyWallet.addressType); // transaction object
  Result result =
      await nodeConnector.broadcast(signedTx.serialize()); // broadcast
  print(' - Transaction is broadcasted: ${result.value}');

  /// need to sync again
  await watchOnlyWallet.fetchOnChainData(nodeConnector);

  /// check the balance again
  print("balance : ${watchOnlyWallet.getBalance()}");

  exit(0);
}
