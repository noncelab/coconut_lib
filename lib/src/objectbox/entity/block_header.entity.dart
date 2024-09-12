import 'dart:convert';
import "dart:typed_data";

import "package:coconut_lib/src/utils/converter.dart";
import "package:objectbox/objectbox.dart";

@Entity()
class BlockHeaderEntity {
  @Id(assignable: true)
  int id = 0;
  @Index()
  int height = 0;
  @Property()
  int timestamp;
  @Property()
  String header;

  @Transient()
  int? version;
  @Transient()
  Uint8List? prevBlockHash;
  @Transient()
  Uint8List? merkleRoot;
  @Transient()
  Uint8List? bits;
  @Transient()
  Uint8List? nonce;

  BlockHeaderEntity(
    this.height,
    this.timestamp,
    this.header, {
    this.version,
    this.prevBlockHash,
    this.merkleRoot,
    this.bits,
    this.nonce,
  });

  factory BlockHeaderEntity.parse(int height, String header) {
    Uint8List bytes = Converter.hexToBytes(header);
    int version = Converter.littleEndianToInt(bytes.sublist(0, 4));
    Uint8List prevBlockHash =
        Uint8List.fromList(bytes.sublist(4, 36).reversed.toList());
    Uint8List merkleRoot =
        Uint8List.fromList(bytes.sublist(36, 68).reversed.toList());
    int timestamp = Converter.littleEndianToInt(bytes.sublist(68, 72));
    Uint8List bits = bytes.sublist(72, 76);
    Uint8List nonce = bytes.sublist(76, 80);

    return BlockHeaderEntity(height, timestamp, header,
        version: version,
        prevBlockHash: prevBlockHash,
        merkleRoot: merkleRoot,
        bits: bits,
        nonce: nonce);
  }

  BlockHeaderEntity.fromJson(Map<String, dynamic> json)
      : height = json['height'],
        timestamp = json['timestamp'],
        header = json['header'],
        version = json['version'],
        prevBlockHash = json['prevBlockHash'] != null
            ? base64Decode(json['prevBlockHash'])
            : null,
        merkleRoot = json['merkleRoot'] != null
            ? base64Decode(json['merkleRoot'])
            : null,
        bits = json['bits'] != null ? base64Decode(json['bits']) : null,
        nonce = json['nonce'] != null ? base64Decode(json['nonce']) : null;

  Map<String, dynamic> toJson() {
    return {
      'height': height,
      'timestamp': timestamp,
      'header': header,
      'version': version,
      'prevBlockHash':
          prevBlockHash != null ? base64Encode(prevBlockHash!) : null,
      'merkleRoot': merkleRoot != null ? base64Encode(merkleRoot!) : null,
      'bits': bits != null ? base64Encode(bits!) : null,
      'nonce': nonce != null ? base64Encode(nonce!) : null,
    };
  }
}
