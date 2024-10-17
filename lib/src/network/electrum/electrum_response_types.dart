import 'package:json_annotation/json_annotation.dart';

part 'electrum_response_types.g.dart';

class ElectrumResponse<T> {
  int? id;
  String? jsonrpc;
  T result;

  factory ElectrumResponse.fromJson(dynamic json, Function parse) {
    ElectrumResponse<T> response = ElectrumResponse(
        result: parse(json['result']),
        jsonrpc: json['jsonrpc'],
        id: json['id']);

    return response;
  }

  ElectrumResponse({required this.result, this.jsonrpc, this.id});
}

@JsonSerializable()
class ServerFeaturesRes {
  @JsonKey(name: 'server_version')
  String serverVersion;
  @JsonKey(name: 'genesis_hash')
  String genesisHash;
  @JsonKey(name: 'protocol_min')
  String protocolMin;
  @JsonKey(name: 'protocol_max')
  String protocolMax;
  @JsonKey(name: 'hash_function')
  String? hashFunction;
  @JsonKey(name: 'pruning')
  int? pruning;
  @JsonKey(name: 'hosts')
  Map<String, HostsPort> hosts;

  ServerFeaturesRes({
    required this.serverVersion,
    required this.genesisHash,
    required this.protocolMin,
    required this.protocolMax,
    required this.hosts,
    this.hashFunction,
    this.pruning,
  });

  Map<String, dynamic> toJson() => _$ServerFeaturesResToJson(this);

  factory ServerFeaturesRes.fromJson(Map<String, dynamic> json) =>
      _$ServerFeaturesResFromJson(json);
}

@JsonSerializable()
class HostsPort {
  @JsonKey(name: 'ssl_port')
  int? sslPort;
  @JsonKey(name: 'tcp_port')
  int? tcpPort;

  HostsPort({this.sslPort, this.tcpPort});

  Map<String, dynamic> toJson() => _$HostsPortToJson(this);

  factory HostsPort.fromJson(Map<String, dynamic> json) =>
      _$HostsPortFromJson(json);
}

@JsonSerializable()
class GetHistoryRes {
  int height;
  @JsonKey(name: 'tx_hash')
  String txHash;

  GetHistoryRes({required this.height, required this.txHash});

  Map<String, dynamic> toJson() => _$GetHistoryResToJson(this);

  factory GetHistoryRes.fromJson(Map<String, dynamic> json) =>
      _$GetHistoryResFromJson(json);

  @override
  bool operator ==(Object other) {
    if (other is GetHistoryRes) {
      return txHash == other.txHash;
    }
    return false;
  }

  @override
  int get hashCode => txHash.hashCode ^ height.hashCode;
}

@JsonSerializable()
class GetMempoolRes {
  int height;
  @JsonKey(name: 'tx_hash')
  String txHash;
  int fee;

  GetMempoolRes(
      {required this.height, required this.txHash, required this.fee});

  Map<String, dynamic> toJson() => _$GetMempoolResToJson(this);

  factory GetMempoolRes.fromJson(Map<String, dynamic> json) =>
      _$GetMempoolResFromJson(json);
}

@JsonSerializable()
class ListUnspentRes {
  int height;
  @JsonKey(name: 'tx_hash')
  String txHash;
  @JsonKey(name: 'tx_pos')
  int txPos;
  int value;

  ListUnspentRes({
    required this.height,
    required this.txHash,
    required this.txPos,
    required this.value,
  });

  factory ListUnspentRes.fromJson(Map<String, dynamic> json) =>
      _$ListUnspentResFromJson(json);
  Map<String, dynamic> toJson() => _$ListUnspentResToJson(this);
}

@JsonSerializable()
class GetHeadersRes {
  int max;
  int count;

  List<int> rawHeaders;
  List<String> headers;

  GetHeadersRes({
    required this.max,
    required this.count,
    required this.rawHeaders,
    this.headers = const [],
  });

  Map<String, dynamic> toJson() => _$GetHeadersResToJson(this);

  factory GetHeadersRes.fromJson(Map<String, dynamic> json) {
    return _$GetHeadersResFromJson(json);
  }
}

@JsonSerializable()
class GetBalanceRes {
  int confirmed;
  int unconfirmed;

  GetBalanceRes({
    required this.confirmed,
    required this.unconfirmed,
  });

  Map<String, dynamic> toJson() => _$GetBalanceResToJson(this);

  factory GetBalanceRes.fromJson(Map<String, dynamic> json) {
    return _$GetBalanceResFromJson(json);
  }
}

@JsonSerializable()
class HeaderNotification {
  int height;
  String header;

  HeaderNotification({
    required this.height,
    required this.header,
  });

  Map<String, dynamic> toJson() => _$HeaderNotificationToJson(this);

  factory HeaderNotification.fromJson(Map<String, dynamic> json) {
    return _$HeaderNotificationFromJson(json);
  }
}

@JsonSerializable()
class RawHeaderNotification {
  int height;
  List<int> header;

  RawHeaderNotification({
    required this.height,
    required this.header,
  });

  Map<String, dynamic> toJson() => _$RawHeaderNotificationToJson(this);

  factory RawHeaderNotification.fromJson(Map<String, dynamic> json) {
    return _$RawHeaderNotificationFromJson(json);
  }
}

@JsonSerializable()
class ScriptNotification {
  String scripthash;
  String status;

  ScriptNotification({required this.scripthash, required this.status});

  Map<String, dynamic> toJson() => _$ScriptNotificationToJson(this);

  factory ScriptNotification.fromJson(Map<String, dynamic> json) {
    return _$ScriptNotificationFromJson(json);
  }
}

@JsonSerializable()
class BlockHeaderSubscribe {
  int height;
  String hex;

  BlockHeaderSubscribe({required this.height, required this.hex});

  Map<String, dynamic> toJson() => _$BlockHeaderSubscribeToJson(this);

  factory BlockHeaderSubscribe.fromJson(Map<String, dynamic> json) {
    return _$BlockHeaderSubscribeFromJson(json);
  }
}
