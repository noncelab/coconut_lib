part of '../../coconut_lib.dart';

class NetworkType {
  /// Mainnet
  static NetworkType mainnet = NetworkType('mainnet', false);

  /// Testnet
  static NetworkType testnet = NetworkType('testnet', true);

  /// Regtest
  static NetworkType regtest = NetworkType('regtest', true);

  static NetworkType _currentNetworkType = NetworkType.testnet;

  final String _name;
  final bool _isTestnet;

  /// Get the current network
  static NetworkType get currentNetworkType => _currentNetworkType;

  /// Get all network values
  static List<NetworkType> get values => [mainnet, testnet, regtest];

  /// Check if it is testnet
  bool get isTestnet => _isTestnet;

  NetworkType(this._name, this._isTestnet);

  /// @nodoc
  @override
  String toString() {
    return _name;
  }

  @override
  int get hashCode => _name.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is NetworkType) {
      return _name == other._name;
    }
    return false;
  }

  /// Set network type
  static void setNetworkType(NetworkType networkType) {
    _currentNetworkType = networkType;
  }

  /// Get network by name (mainnet, testnet, regtest)
  static NetworkType getNetworkType(String network) {
    switch (network) {
      case 'mainnet':
        return mainnet;
      case 'testnet':
        return testnet;
      case 'regtest':
        return regtest;
      default:
        throw Exception('Invalid network type');
    }
  }
}
