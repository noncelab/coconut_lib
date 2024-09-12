import 'package:coconut_lib/coconut_lib.dart';
import 'package:objectbox/objectbox.dart';

import 'address_book.entity.dart';

@Entity()
class AddressEntity {
  @Id()
  int id = 0;

  @Index()
  String address;

  @Property()
  bool isUsed = false;

  @Property()
  String derivationPath;

  @Index()
  int index;

  @Property()
  int amount = 0;

  final receiveBook = ToOne<AddressBookEntity>();
  final changeBook = ToOne<AddressBookEntity>();

  AddressEntity({
    required this.address,
    required this.isUsed,
    required this.derivationPath,
    required this.index,
    required this.amount,
  });

  Address toAddress() {
    return Address(address, derivationPath, index, isUsed, amount);
  }
}
