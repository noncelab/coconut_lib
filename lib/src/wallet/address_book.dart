part of '../../coconut_lib.dart';

/// Represents an address list information in every wallet.
class AddressBook {
  final int _gapLimit = 20;

  /// @nodoc
  int usedReceive = -1;

  /// @nodoc
  int usedChange = -1;

  final HashMap<String, Address> _receiveBook = HashMap<String, Address>();
  final HashMap<String, Address> _changeBook = HashMap<String, Address>();

  /// The gap limit of the address.
  int get gapLimit => _gapLimit;

  /// The receive address book.
  HashMap<String, Address> get receiveBook => _receiveBook;

  /// The change address book.
  HashMap<String, Address> get changeBook => _changeBook;

  /// @nodoc
  AddressBook();

  /// @nodoc
  AddressBook.fromEntity(AddressBookEntity entity) {
    usedReceive = entity.usedReceiveIndex;
    usedChange = entity.usedChangeIndex;
    _receiveBook.addAll(entity.getReceiveMap());
    _changeBook.addAll(entity.getChangeMap());
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
          _changeBook[address.address] = address;
        }
      } else {
        if (!receiveBook.containsKey(address.address)) {
          _receiveBook[address.address] = address;
        }
      }
    }
  }
}
