// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'electrum_res_types.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerFeaturesRes _$ServerFeaturesResFromJson(Map<String, dynamic> json) =>
    ServerFeaturesRes(
      serverVersion: json['server_version'] as String,
      genesisHash: json['genesis_hash'] as String,
      protocolMin: json['protocol_min'] as String,
      protocolMax: json['protocol_max'] as String,
      hosts: (json['hosts'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, HostsPort.fromJson(e as Map<String, dynamic>)),
      ),
      hashFunction: json['hash_function'] as String?,
      pruning: (json['pruning'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ServerFeaturesResToJson(ServerFeaturesRes instance) =>
    <String, dynamic>{
      'server_version': instance.serverVersion,
      'genesis_hash': instance.genesisHash,
      'protocol_min': instance.protocolMin,
      'protocol_max': instance.protocolMax,
      'hash_function': instance.hashFunction,
      'pruning': instance.pruning,
      'hosts': instance.hosts,
    };

HostsPort _$HostsPortFromJson(Map<String, dynamic> json) => HostsPort(
      sslPort: (json['ssl_port'] as num?)?.toInt(),
      tcpPort: (json['tcp_port'] as num?)?.toInt(),
    );

Map<String, dynamic> _$HostsPortToJson(HostsPort instance) => <String, dynamic>{
      'ssl_port': instance.sslPort,
      'tcp_port': instance.tcpPort,
    };

GetHistoryRes _$GetHistoryResFromJson(Map<String, dynamic> json) =>
    GetHistoryRes(
      height: (json['height'] as num).toInt(),
      txHash: json['tx_hash'] as String,
    );

Map<String, dynamic> _$GetHistoryResToJson(GetHistoryRes instance) =>
    <String, dynamic>{
      'height': instance.height,
      'tx_hash': instance.txHash,
    };

GetMempoolRes _$GetMempoolResFromJson(Map<String, dynamic> json) =>
    GetMempoolRes(
      height: (json['height'] as num).toInt(),
      txHash: json['tx_hash'] as String,
      fee: (json['fee'] as num).toInt(),
    );

Map<String, dynamic> _$GetMempoolResToJson(GetMempoolRes instance) =>
    <String, dynamic>{
      'height': instance.height,
      'tx_hash': instance.txHash,
      'fee': instance.fee,
    };

ListUnspentRes _$ListUnspentResFromJson(Map<String, dynamic> json) =>
    ListUnspentRes(
      height: (json['height'] as num).toInt(),
      txHash: json['tx_hash'] as String,
      txPos: (json['tx_pos'] as num).toInt(),
      value: (json['value'] as num).toInt(),
    );

Map<String, dynamic> _$ListUnspentResToJson(ListUnspentRes instance) =>
    <String, dynamic>{
      'height': instance.height,
      'tx_hash': instance.txHash,
      'tx_pos': instance.txPos,
      'value': instance.value,
    };

GetHeadersRes _$GetHeadersResFromJson(Map<String, dynamic> json) =>
    GetHeadersRes(
      max: (json['max'] as num).toInt(),
      count: (json['count'] as num).toInt(),
      rawHeaders: (json['rawHeaders'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      headers: (json['headers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$GetHeadersResToJson(GetHeadersRes instance) =>
    <String, dynamic>{
      'max': instance.max,
      'count': instance.count,
      'rawHeaders': instance.rawHeaders,
      'headers': instance.headers,
    };

GetBalanceRes _$GetBalanceResFromJson(Map<String, dynamic> json) =>
    GetBalanceRes(
      confirmed: (json['confirmed'] as num).toInt(),
      unconfirmed: (json['unconfirmed'] as num).toInt(),
    );

Map<String, dynamic> _$GetBalanceResToJson(GetBalanceRes instance) =>
    <String, dynamic>{
      'confirmed': instance.confirmed,
      'unconfirmed': instance.unconfirmed,
    };

HeaderNotification _$HeaderNotificationFromJson(Map<String, dynamic> json) =>
    HeaderNotification(
      height: (json['height'] as num).toInt(),
      header: json['header'] as String,
    );

Map<String, dynamic> _$HeaderNotificationToJson(HeaderNotification instance) =>
    <String, dynamic>{
      'height': instance.height,
      'header': instance.header,
    };

RawHeaderNotification _$RawHeaderNotificationFromJson(
        Map<String, dynamic> json) =>
    RawHeaderNotification(
      height: (json['height'] as num).toInt(),
      header: (json['header'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$RawHeaderNotificationToJson(
        RawHeaderNotification instance) =>
    <String, dynamic>{
      'height': instance.height,
      'header': instance.header,
    };

ScriptNotification _$ScriptNotificationFromJson(Map<String, dynamic> json) =>
    ScriptNotification(
      scripthash: json['scripthash'] as String,
      status: json['status'] as String,
    );

Map<String, dynamic> _$ScriptNotificationToJson(ScriptNotification instance) =>
    <String, dynamic>{
      'scripthash': instance.scripthash,
      'status': instance.status,
    };

BlockHeaderSubscribe _$BlockHeaderSubscribeFromJson(
        Map<String, dynamic> json) =>
    BlockHeaderSubscribe(
      height: (json['height'] as num).toInt(),
      hex: json['hex'] as String,
    );

Map<String, dynamic> _$BlockHeaderSubscribeToJson(
        BlockHeaderSubscribe instance) =>
    <String, dynamic>{
      'height': instance.height,
      'hex': instance.hex,
    };
