part of '../../coconut_lib.dart';

/// Represents the base class of a wallet and vault.
abstract class WalletBase {
  // late String _identifier;
  final AddressType _addressType;
  final String _derivationPath;
  final int _accountIndex = 0;
  late final Descriptor _descriptor;

  late AddressBook addressBook;

  /// Get the identifier of the wallet.
  int get identifier => Hash.getSimpleHash(_descriptor.serialize());

  /// Get the address type of the wallet.
  AddressType get addressType => _addressType;

  /// Get the derivation path of the wallet.
  String get derivationPath => _derivationPath;

  /// Get the account index of the wallet.
  int get accountIndex => _accountIndex;

  /// Get the descriptor of the wallet.
  String get descriptor => _descriptor.serialize();

  /// @nodoc
  WalletBase(this._addressType, this._derivationPath) {
    addressBook = AddressBook(this);
  }

  /// Get the address of the given index.
  String getAddress(int addressIndex, {bool isChange = false});

  ///get Address object for receive
  Address getReceiveAddress() {
    int index = addressBook.usedReceive + 1;
    return addressBook.getAddress(index, false);
  }

  /// get Address object for change
  Address getChangeAddress() {
    int index = addressBook.usedChange + 1;
    return addressBook.getAddress(index, true);
  }

  /// get Address list from the address book
  List<Address> getAddressList(int cursor, int count, bool isChange) {
    List<Address> addressList = [];
    for (int i = cursor; i < cursor + count; i++) {
      addressList.add(addressBook.getAddress(i, isChange));
    }
    return addressList;
  }
}
