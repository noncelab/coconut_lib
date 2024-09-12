import 'package:coconut_lib/coconut_lib.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class TransactionEntity {
  @Id(assignable: true)
  int id = 0;
  @Index()
  int walletId;
  @Index()
  String txHash;
  @Property()
  String txString;
  @Property()
  int? timestamp;
  @Property()
  int? height;
  @Property()
  List<String> prevTxStringList;

  @Transient()
  String? _memo;

  String get memo => _memo ?? '';
  set memo(String memo) {
    _memo = memo;
  }

  TransactionEntity({
    required this.walletId,
    required this.txHash,
    required this.txString,
    required this.prevTxStringList,
    this.timestamp,
    this.height,
  });

  TransactionEntity.from(this.walletId, this.txString, this.prevTxStringList,
      {this.height, this.timestamp})
      : txHash = Transaction.parse(txString).transactionHash;

  Transaction convert() {
    return Transaction.parse(txString);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! TransactionEntity) {
      return false;
    }

    final otherEntity = other;

    if (txHash == otherEntity.txHash && walletId == otherEntity.walletId) {
      return true;
    }

    return false;
  }

  @override
  int get hashCode => walletId.hashCode ^ txHash.hashCode;

  TransactionEntity.fromJson(Map<String, dynamic> json)
      : walletId = json['walletId'],
        txHash = json['txHash'],
        txString = json['txString'],
        prevTxStringList = List<String>.from(json['prevTxStringList']),
        timestamp = json['timestamp'],
        height = json['height'],
        id = json['id'],
        _memo = json['memo'];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletId': walletId,
      'txHash': txHash,
      'txString': txString,
      'timestamp': timestamp,
      'height': height,
      'prevTxStringList': prevTxStringList,
      'memo': _memo,
    };
  }
}
