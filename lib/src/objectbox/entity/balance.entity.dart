import 'package:objectbox/objectbox.dart';

@Entity()
class BalanceEntity {
  @Id()
  int id = 0;

  @Unique(onConflict: ConflictStrategy.replace)
  int walletId;

  @Property()
  int confirmed;

  @Property()
  int unconfirmed;

  BalanceEntity(
      {required this.walletId,
      required this.confirmed,
      required this.unconfirmed});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletId': walletId,
      'confirmed': confirmed,
      'unconfirmed': unconfirmed,
    };
  }

  BalanceEntity.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        walletId = json['walletId'],
        confirmed = json['confirmed'],
        unconfirmed = json['unconfirmed'];
}
