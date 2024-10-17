part of '../../coconut_lib.dart';

/// Represents a single signature wallet.
class SingleSignatureWallet extends SingleSignatureWalletBase
    implements WalletFeature {
  @override
  late WalletStatus? walletStatus;

  /// Creates a new single signature wallet.
  SingleSignatureWallet(
      String fingerprint,
      HDWallet wallet,
      AddressType addressType,
      String derivationPath,
      ExtendedPublicKey extendedPublicKey)
      : super(KeyStore(fingerprint, wallet, extendedPublicKey), addressType,
            derivationPath, false);

  /// Create a single signature wallet from descriptor.
  factory SingleSignatureWallet.fromDescriptor(String descriptor) {
    Descriptor descriptorObject = Descriptor.parse(descriptor);
    AddressType addressType;
    if (descriptorObject.scriptType == "sh-wpkh") {
      addressType = AddressType.p2wpkhInP2sh;
    } else {
      addressType = AddressType.getAddressTypeFromScriptType(
          'P2${descriptorObject.scriptType}');
    }

    if (addressType.isMultisig) {
      throw Exception(
          '${addressType.getAddress} is multisig script. Use MultsignatureVault Class.');
    }

    ExtendedPublicKey extendedPublicKey =
        ExtendedPublicKey.parse(descriptorObject.getPublicKey(0));
    HDWallet wallet = HDWallet.fromPublicKey(
        extendedPublicKey.publicKey, extendedPublicKey.chainCode);
    return SingleSignatureWallet(descriptorObject.getFingerprint(0), wallet,
        addressType, descriptorObject.getDerivationPath(0), extendedPublicKey);
  }

  /// Get Json string of the single signature wallet.
  String toJson() {
    return jsonEncode({'descriptor': descriptor});
  }

  /// Parse the single signature wallet from json string.
  factory SingleSignatureWallet.fromJson(String jsonStr) {
    Map<String, dynamic> json = jsonDecode(jsonStr);
    return SingleSignatureWallet.fromDescriptor(json['descriptor']);
  }

  @override
  int getBalance() {
    return walletStatus!.balance.confirmed;
  }

  @override
  int getUnconfirmedBalance() {
    return walletStatus!.balance.unconfirmed;
  }

  @override
  List<UTXO> getUtxoList(
      {UtxoOrderEnum order = UtxoOrderEnum.byTimestampDesc}) {
    UTXO.sortUTXO(walletStatus!.utxoList, order);
    return walletStatus!.utxoList;
  }

  @override
  List<Transfer> getTransferList({int cursor = 0, int count = 5}) {
    List<Transfer> transferList = [];
    for (Transaction entity in walletStatus!.transactionList) {
      transferList.add(Transfer.fromTransactions(addressBook, entity));
    }
    return transferList;
  }

  @override
  Future<String> generatePsbt(
      String receiverAddress, int sendingAmount, int feeRate) async {
    PSBT psbt = await Future(
        () => PSBT.forSending(receiverAddress, sendingAmount, feeRate, this));
    return psbt.serialize();
  }

  @override
  Future<String> generatePsbtWithMaximum(
      String receiverAddress, int feeRate) async {
    PSBT psbt = await Future(
        () => PSBT.forMaximumSending(receiverAddress, feeRate, this));
    return psbt.serialize();
  }

  @override
  Future<int> estimateFee(
      String receiverAddress, int sendingAmount, int feeRate) async {
    PSBT psbt = await Future(
        () => PSBT.forSending(receiverAddress, sendingAmount, feeRate, this));
    return psbt.estimateFee(feeRate, addressType);
  }

  @override
  Future<int> estimateFeeWithMaximum(
      String receiverAddress, int feeRate) async {
    PSBT psbt = await Future(
        () => PSBT.forMaximumSending(receiverAddress, feeRate, this));
    return psbt.estimateFee(feeRate, addressType);
  }

  @override
  Future<void> fetchOnChainData(NodeConnector nodeConnector) async {
    var syncResult = await nodeConnector.fetch(this);
    if (syncResult.isFailure) {
      throw Exception(" - Sync failed : ${syncResult.error}");
    } else {
      walletStatus = syncResult.value;
      addressBook.updateAddressBook();
    }
  }

  @override
  void saveStatus() {
    walletStatus!.persist(identifier);
  }

  @override
  Future<void> loadStatus() async {
    walletStatus = await WalletStatus.load(identifier);
    addressBook.updateAddressBook();
  }
}
