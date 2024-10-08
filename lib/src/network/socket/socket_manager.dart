part of '../../../../coconut_lib.dart';

class SocketManager {
  /// Socket
  final SocketFactory socketFactory;
  Socket? _socket;
  SocketConnectionStatus _connectionStatus =
      SocketConnectionStatus.reconnecting;
  int _connectionAttempts = 0;
  final int _maxConnectionAttempts;
  final int _reconnectDelaySeconds;

  SocketConnectionStatus get connectionStatus => _connectionStatus;

  /// Connection info
  late String _host;
  late int _port;
  late bool _ssl;

  /// JSON parse
  final StreamController<String> _streamController = StreamController();
  final StringBuffer _buffer = StringBuffer();
  int _braceCount = 0;
  bool _inString = false;

  /// Response
  final Map<int, Completer<dynamic>> _completerMap = {};

  /// On Reconnect callback
  void Function()? onReconnect;

  /// [factory]: 테스트용 모킹 객체를 주입하기 위한 클래스로 실제 사용 시 별도로 지정하지 않아도 됨 <br/>
  /// [maxConnectionAttempts]: 최대 연결 시도 횟수, default: 30 <br/>
  /// [reconnectDelaySeconds]: 재연결 주기, default: 10 (s) <br/>
  SocketManager(
      {SocketFactory? factory,
      maxConnectionAttempts = 30,
      reconnectDelaySeconds = 10})
      : socketFactory = factory ?? DefaultSocketFactory(),
        _maxConnectionAttempts = maxConnectionAttempts,
        _reconnectDelaySeconds = reconnectDelaySeconds {
    _streamController.stream.listen(_handleResponse);
  }

  setCompleter(int id, Completer completer) {
    _completerMap[id] = completer;
  }

  Future<void> connect(String host, int port, {bool ssl = true}) async {
    _host = host;
    _port = port;
    _ssl = ssl;

    if (_connectionAttempts >= _maxConnectionAttempts) {
      _connectionStatus = SocketConnectionStatus.terminated;
      return;
    }

    ++_connectionAttempts;

    if (_connectionAttempts > 1) {
      print(
          'Retrying to connect to $host:$port ($_connectionAttempts/$_maxConnectionAttempts)');
    }

    if (_connectionStatus != SocketConnectionStatus.reconnecting) {
      return;
    }

    _connectionStatus = SocketConnectionStatus.connecting;
    try {
      if (ssl) {
        _socket = await socketFactory.createSecureSocket(host, port);
      } else {
        _socket = await socketFactory.createSocket(host, port);
      }
      _connectionStatus = SocketConnectionStatus.connected;
      _connectionAttempts = 0;
      _socket!.listen(_onData,
          onError: _onError, onDone: _onDone, cancelOnError: true);
    } catch (e) {
      print('error: $e');
      _connectionStatus = SocketConnectionStatus.reconnecting;
      _scheduleReconnect(host, port, ssl: ssl);
    }
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _connectionStatus = SocketConnectionStatus.reconnecting;
  }

  void _onData(Uint8List data) {
    _streamController.add(utf8.decode(data));
  }

  void _onDone() {
    print('Connection closed.');
    _connectionStatus = SocketConnectionStatus.reconnecting;
    _scheduleReconnect(_host, _port, ssl: _ssl);
  }

  void _onError(error) {
    print('Connection error: $error');
    _connectionStatus = SocketConnectionStatus.reconnecting;
    _scheduleReconnect(_host, _port, ssl: _ssl);
  }

  Future<void> send(String data) async {
    if (_connectionStatus == SocketConnectionStatus.reconnecting) {
      await connect(_host, _port, ssl: _ssl);
    }
    try {
      _socket!.writeln(data);
    } catch (e) {
      _connectionStatus = SocketConnectionStatus.reconnecting;
      rethrow;
    }
  }

  void _scheduleReconnect(String host, int port, {bool ssl = true}) {
    print('After $_reconnectDelaySeconds seconds, it will try to reconnect.');
    Future.delayed(Duration(seconds: _reconnectDelaySeconds), () {
      connect(host, port, ssl: ssl).then((any) {
        onReconnect?.call();
      });
    });
  }

  void _handleResponse(String data) {
    _buffer.write(data);

    String bufferString = _buffer.toString();
    int i = 0;

    while (i < bufferString.length) {
      var char = bufferString[i];

      if (char == '"' && (i == 0 || bufferString[i - 1] != '\\')) {
        _inString = !_inString;
      }

      if (!_inString) {
        if (char == '{') {
          _braceCount++;
        } else if (char == '}') {
          _braceCount--;
        }
      }

      i++;

      if (_braceCount == 0 && !_inString) {
        var jsonString = bufferString.substring(0, i).trim();

        if (jsonString.isNotEmpty) {
          try {
            var jsonObject = json.decode(jsonString);
            _processJsonObject(jsonObject);
          } catch (e) {
            print('Failed to parse JSON: $jsonString');
          }
        }

        bufferString = bufferString.substring(i).trim();
        _buffer.clear();
        _buffer.write(bufferString);

        i = 0;
      }
    }

    if (bufferString.trim().isNotEmpty) {
      _braceCount--;
      _inString = false;
    }
  }

  void _processJsonObject(Map<String, dynamic> jsonObject) {
    final id = jsonObject['id'];
    if (_completerMap.containsKey(id)) {
      _completerMap[id]!.complete(jsonObject);
      _completerMap.remove(id);
    }
  }
}
