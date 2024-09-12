import 'dart:collection';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:objectbox/objectbox.dart';

import 'address.entity.dart';

@Entity()
class AddressBookEntity {
  @Id()
  int id = 0;

  @Index()
  int walletId;

  @Property()
  int usedReceiveIndex = -1;

  @Property()
  int usedChangeIndex = -1;

  @Property()
  int maxReceiveIndex = 0;

  @Property()
  int maxChangeIndex = 0;

  @Backlink('receiveBook')
  final receiveList = ToMany<AddressEntity>();

  @Backlink('changeBook')
  final changeList = ToMany<AddressEntity>();

  AddressBookEntity({required this.walletId});

  HashMap<String, Address> getReceiveMap() {
    HashMap<String, Address> map = HashMap<String, Address>();

    for (var receive in receiveList) {
      var address = Address(receive.address, receive.derivationPath,
          receive.index, receive.isUsed, receive.amount);

      map[receive.address] = address;
    }

    return map;
  }

  HashMap<String, Address> getChangeMap() {
    HashMap<String, Address> map = HashMap<String, Address>();

    for (var change in changeList) {
      var address = Address(change.address, change.derivationPath, change.index,
          change.isUsed, change.amount);

      map[change.address] = address;
    }

    return map;
  }
}
