part of '../../coconut_lib.dart';

/// Represents an address list information in every wallet.
class AddressBook {
  final int _gapLimit = 20;

  /// @nodoc
  int usedReceive = -1;

  /// @nodoc
  int usedChange = -1;

  final WalletBase _wallet;

  /// @nodoc
  WalletStatus? get walletStatus => () {
        late WalletFeature walletFeature;
        try {
          walletFeature = _wallet as WalletFeature;
        } catch (e) {
          print("Vault does not have wallet status");
        }
        return walletFeature.walletStatus;

        // if (_wallet is SingleSignatureWallet) {
        //   return _wallet.walletStatus;
        // } else if (_wallet is MultisignatureWallet) {
        //   return _wallet.walletStatus;
        // }
        // return null;
      }();

  late final List<Address> _receiveList = [];
  late final List<Address> _changeList = [];

  /// List of receive addresses
  List<Address> get receiveList => _receiveList;

  /// List of change addresses
  List<Address> get changeList => _changeList;

  /// receive address map address - address object
  HashMap<String, Address> get receiveBook =>
      HashMap.fromEntries(receiveList.map((e) => MapEntry(e.address, e)));

  /// change address map address - address object
  HashMap<String, Address> get changeBook =>
      HashMap.fromEntries(changeList.map((e) => MapEntry(e.address, e)));

  /// The gap limit of the address.
  int get gapLimit => _gapLimit;

  /// @nodoc
  AddressBook(this._wallet) {
    int maxReceiveIndex = _gapLimit;
    int maxChangeIndex = _gapLimit;

    for (int i = 0; i < maxReceiveIndex; i++) {
      receiveList.add(_generateAddress(i, false));
    }

    for (int j = 0; j < maxChangeIndex; j++) {
      changeList.add(_generateAddress(j, true));
    }
  }

  /// get derivation path of the address
  String getDerivationPath(String address) {
    if (receiveBook.containsKey(address)) {
      return receiveBook[address]!.derivationPath;
    } else if (changeBook.containsKey(address)) {
      return changeBook[address]!.derivationPath;
    }
    throw Exception('Address not found');
  }

  /// check if the address is in the address book
  bool contains(String address) {
    if (receiveBook.containsKey(address)) {
      return true;
    } else if (changeBook.containsKey(address)) {
      return true;
    }
    return false;
  }

  /// check if the address is in the receive address book
  bool containsInReceive(String address) {
    if (receiveBook.containsKey(address)) {
      return true;
    }
    return false;
  }

  /// check if the address is in the change address book
  bool containsInChange(String address) {
    if (changeBook.containsKey(address)) {
      return true;
    }
    return false;
  }

  /// get the address object from the address book
  Address getAddressObject(String address) {
    if (receiveBook.containsKey(address)) {
      return receiveBook[address]!;
    } else if (changeBook.containsKey(address)) {
      return changeBook[address]!;
    }
    throw Exception('Address not found');
  }

  /// @nodoc
  void addAddressList(List<Address> addressList, bool isChange) {
    for (Address address in addressList) {
      if (isChange) {
        if (!changeBook.containsKey(address.address)) {
          changeBook[address.address] = address;
        }
      } else {
        if (!receiveBook.containsKey(address.address)) {
          receiveBook[address.address] = address;
        }
      }
    }
  }

  /// get the address object from index
  Address getAddress(int index, bool isChange) {
    if (isChange) {
      if (index >= changeList.length) {
        for (int i = changeList.length; i <= index; i++) {
          changeList.add(_generateAddress(i, isChange));
        }
      }
      return changeList[index];
    } else {
      if (index >= receiveList.length) {
        for (int i = receiveList.length; i <= index; i++) {
          receiveList.add(_generateAddress(i, isChange));
        }
      }
      return receiveList[index];
    }
  }

  /// @nodoc
  Address _generateAddress(int index, bool isChange) {
    String address = '';

    if (_wallet is SingleSignatureWalletBase) {
      address = _wallet.addressType
          .getAddress(_wallet.keyStore.getPublicKey(index, isChange: isChange));
    } else if (_wallet is MultisignatureWalletBase) {
      address = _wallet.addressType.getMultisignatureAddress(
          _wallet.keyStoreList
              .map((e) => e.getPublicKey(index, isChange: isChange))
              .toList(),
          _wallet.requiredSignature);
    }
    String derivationPath =
        '${_wallet.derivationPath}/${isChange ? 1 : 0}/$index';

    return Address(address, derivationPath, index, false, 0);
  }

  /// update address book with the wallet status
  void updateAddressBook() {
    if (walletStatus != null) {
      int maxReceiveIndex = walletStatus!.receiveMaxGap;
      int maxChangeIndex = walletStatus!.changeMaxGap;

      for (int i = receiveList.length; i < maxReceiveIndex; i++) {
        receiveList.add(_generateAddress(i, false));
      }

      for (int j = changeList.length; j < maxChangeIndex; j++) {
        changeList.add(_generateAddress(j, true));
      }

      for (int used in walletStatus!.receiveUsedIndexList) {
        receiveList[used].setUsed(true);
      }

      if (walletStatus!.receiveUsedIndexList.isNotEmpty) {
        usedReceive =
            walletStatus!.receiveUsedIndexList.reduce((a, b) => a > b ? a : b);
      }

      for (int used in walletStatus!.changeUsedIndexList) {
        changeList[used].setUsed(true);
      }

      if (walletStatus!.changeUsedIndexList.isNotEmpty) {
        usedChange =
            walletStatus!.changeUsedIndexList.reduce((a, b) => a > b ? a : b);
      }

      for (int index in walletStatus!.receiveAddressBalanceMap.keys) {
        receiveList[index]
            .setAmount(walletStatus!.receiveAddressBalanceMap[index]!);
      }

      for (int index in walletStatus!.changeAddressBalanceMap.keys) {
        changeList[index]
            .setAmount(walletStatus!.changeAddressBalanceMap[index]!);
      }
    }
  }
}
