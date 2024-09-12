part of '../../coconut_lib.dart';

/// Represents a multisignature wallet.
class MultisignatureWallet extends MultisignatureWalletBase
    implements WalletFeature {
  /// @nodoc
  MultisignatureWallet(super.requiredSignature, super.addressType,
      super.derivationPath, super.keyStores);

  /// Create a multisignature wallet from descriptor.
  factory MultisignatureWallet.fromDescriptor(String descriptor) {
    Descriptor descriptorObject = Descriptor.parse(descriptor);
    AddressType addressType;
    if (descriptorObject.scriptType == "sh-wpkh") {
      addressType = AddressType.p2wpkhInP2sh;
    } else {
      addressType = AddressType.getAddressTypeFromScriptType(
          'P2${descriptorObject.scriptType}');
    }

    if (!addressType.isMultisig) {
      throw Exception('Use ${addressType.getAddress} is not multisig script.');
    }

    List<KeyStore> keyStores = [];
    String derivationPath = descriptorObject.getDerivationPath(0);

    for (int i = 0; i < descriptorObject.totalSignature; i++) {
      String fingerprint = descriptorObject.getFingerprint(i);
      ExtendedPublicKey extendedPublicKey =
          ExtendedPublicKey.parse(descriptorObject.getPublicKey(i));
      HDWallet wallet = HDWallet.fromPublicKey(
          extendedPublicKey.publicKey, extendedPublicKey.chainCode);
      if (derivationPath != descriptorObject.getDerivationPath(i)) {
        throw Exception('Derivation Path is not same for all public keys');
      }
      keyStores.add(KeyStore(fingerprint, wallet, extendedPublicKey));
    }

    return MultisignatureWallet(descriptorObject.requiredSignatures,
        addressType, descriptorObject.getDerivationPath(0), keyStores);
  }

  /// Get Json string of the multisignature wallet.
  String toJson() {
    return jsonEncode({'descriptor': descriptor});
  }

  /// Parse the multisignature wallet from json string.
  factory MultisignatureWallet.fromJson(String jsonStr) {
    Map<String, dynamic> json = jsonDecode(jsonStr);
    return MultisignatureWallet.fromDescriptor(json['descriptor']);
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
