import 'package:coconut_lib/src/network/electrum/electrum_res_types.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class UtxoEntity {
  @Id(assignable: true)
  int id = 0;
  @Index()
  int walletId;
  @Property()
  int amount;
  @Index()
  String txHash;
  @Property()
  int index;
  @Property()
  String txString;
  @Property()
  String derivationPath;
  @Index()
  int timestamp;
  @Index()
  int height;

  UtxoEntity({
    required this.walletId,
    required this.txHash,
    required this.amount,
    required this.index,
    required this.txString,
    required this.derivationPath,
    required this.timestamp,
    required this.height,
  });

  factory UtxoEntity.fromApiResponse(
      {required int walletId,
      required ListUnspentRes res,
      required String txString,
      required String derivationPath,
      required int timestamp}) {
    return UtxoEntity(
        walletId: walletId,
        txHash: res.txHash,
        amount: res.value,
        index: res.txPos,
        txString: txString,
        derivationPath: derivationPath,
        timestamp: timestamp,
        height: res.height);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletId': walletId,
      'amount': amount,
      'txHash': txHash,
      'index': index,
      'txString': txString,
      'derivationPath': derivationPath,
      'timestamp': timestamp,
      'height': height,
    };
  }

  UtxoEntity.fromJson(Map<String, dynamic> json)
      : walletId = json['walletId'],
        txHash = json['txHash'],
        amount = json['amount'],
        index = json['index'],
        txString = json['txString'],
        derivationPath = json['derivationPath'],
        timestamp = json['timestamp'],
        height = json['height'],
        id = json['id'];
}
