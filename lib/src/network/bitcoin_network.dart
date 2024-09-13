part of '../../coconut_lib.dart';

/// This class is for Bitcoin network configuration.
class BitcoinNetwork {
  final String _name;
  final bool _isTestnet;

  /// Check if it is testnet
  bool get isTestnet => _isTestnet;

  BitcoinNetwork(this._name, this._isTestnet);

  /// Current network
  static BitcoinNetwork _currentNetwork = BitcoinNetwork.testnet;

  /// Get current network configuration
  static BitcoinNetwork get currentNetwork => _currentNetwork;

  /// Change Bitcoin network
  static setNetwork(BitcoinNetwork network) {
    _currentNetwork = network;
  }

  /// Mainnet
  static BitcoinNetwork mainnet = BitcoinNetwork('mainnet', false);

  /// Testnet
  static BitcoinNetwork testnet = BitcoinNetwork('testnet', true);

  /// Regtest
  static BitcoinNetwork regtest = BitcoinNetwork('regtest', true);

  /// Get all network values
  static List<BitcoinNetwork> get values => [mainnet, testnet, regtest];

  /// Get network by name (mainnet, testnet, regtest)
  static BitcoinNetwork getNetwork(String network) {
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

  /// @nodoc
  @override
  String toString() {
    return _name;
  }

  @override
  int get hashCode => _name.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is BitcoinNetwork) {
      return _name == other._name;
    }
    return false;
  }
}
