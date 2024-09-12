enum MnemonicWordCount { word12, word24 }

enum KeyChain { external, internal }

enum ConnectionTypeEnum { electrum, rpc }

enum UtxoOrderEnum { byAmountDesc, byTimestampDesc }

enum TransactionTypeEnum {
  received('RECEIVED'),
  sent('SENT'),
  unknown('UNKNOWN'),
  self('SELF');

  const TransactionTypeEnum(this.name);

  final String name;
}

enum SocketConnectionStatus { reconnecting, connecting, connected, terminated }

enum ErrorCodeEnum {
  invalidParameter('INVALID_PARAMETER'),
  electrumRpcError('ELECTRUM_RPC_ERROR'),
  exceededFee('EXCEEDED_FEE'),
  unknownError('UNKNOWN_ERROR'),
  alreadySyncing('ALREADY_SYNCING'),
  notFound('NOT_FOUND'),
  networkDisconnected('NETWORK_DISCONNECTED');

  const ErrorCodeEnum(this.displayCode);

  final String displayCode;
}
