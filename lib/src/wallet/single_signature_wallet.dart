part of '../../coconut_lib.dart';

/// Represents a single signature wallet.
class SingleSignatureWallet extends SingleSignatureWalletBase
    implements WalletFeature {
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

  /// Create a single signature wallet from extended public key.
  factory SingleSignatureWallet.fromExtendedPublicKey(
      String extendedPublicKey) {
    ExtendedPublicKey pubKey = ExtendedPublicKey.parse(extendedPublicKey);

    if (pubKey.version != AddressType.p2wpkh.versionForMainnet &&
        pubKey.version != AddressType.p2wpkh.versionForTestnet) {
      throw Exception('Not supported Extended Public Key Version');
    }
    HDWallet wallet =
        HDWallet.fromPublicKey(pubKey.publicKey, pubKey.chainCode);
    return SingleSignatureWallet(
        pubKey.parentFingerprint, wallet, AddressType.p2wpkh, '', pubKey);
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
    return Repository()._getBalance(identifier).confirmed;
  }

  @override
  int getUnconfirmedBalance() {
    return Repository()._getBalance(identifier).unconfirmed;
  }

  @override
  List<Transfer> getTransferList({int cursor = 0, int count = 5}) {
    List<TransactionEntity> entityList = Repository()
        ._getTransactionEntityList(this, take: count, cursor: cursor);
    List<Transfer> transferList = [];
    for (TransactionEntity entity in entityList) {
      transferList.add(Transfer.fromRepository(addressBook, entity));
    }
    return transferList;
  }

  @override
  List<UTXO> getUtxoList(
      {UtxoOrderEnum order = UtxoOrderEnum.byTimestampDesc}) {
    List<UTXO> utxoList = [];
    for (UtxoEntity entity
        in Repository()._getUtxoEntityList(identifier, order: order)) {
      utxoList.add(UTXO.fromRepository(entity));
    }
    return utxoList;
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
}
