import 'package:objectbox/objectbox.dart';

class EntityName {
  static final String transaction = 'transaction';

  static final String utxo = 'utxo';

  static final String block = 'block';
}

@Entity()
class CustomIdEntity {
  @Id()
  int id = 0;

  @Index()
  String entityName;

  @Unique(onConflict: ConflictStrategy.fail)
  int customId;

  /// see [EntityName] class
  CustomIdEntity(this.entityName, this.customId);
}
