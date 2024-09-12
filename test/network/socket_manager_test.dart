@Tags(['unit'])
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'socket_manager_test.mocks.dart';

class Callback extends Mock {
  void call();
}

@GenerateMocks([Socket, SecureSocket, SocketFactory, Callback])
void main() {
  group('SocketManager', () {
    late MockSocket mockSocket;
    late MockSocketFactory mockSocketFactory;
    late MockSocketFactory mockErrorSocketFactory;
    late SocketManager socketManager;
    late MockCallback mockCallback;

    setUp(() async {
      mockSocket = MockSocket();
      mockSocketFactory = MockSocketFactory();
      mockErrorSocketFactory = MockSocketFactory();
      socketManager = SocketManager(factory: mockSocketFactory);
      mockCallback = MockCallback();
      when(mockSocketFactory.createSocket('localhost', 1234))
          .thenAnswer((e) async => mockSocket);
      when(mockErrorSocketFactory.createSocket('localhost', 1234))
          .thenThrow(Error());
      when(mockSocket.listen(any,
              onError: anyNamed('onError'),
              onDone: anyNamed('onDone'),
              cancelOnError: anyNamed('cancelOnError')))
          .thenAnswer((invocation) =>
              StreamController<Uint8List>().stream.listen(null));
    });

    test('should connect to server successfully', () async {
      await socketManager.connect('localhost', 1234, ssl: false);

      expect(socketManager.connectionStatus, SocketConnectionStatus.connected);
      verify(mockSocketFactory.createSocket('localhost', 1234)).called(1);
    });

    test('should handle socket data', () async {
      when(mockSocket.listen(any,
              onError: anyNamed('onError'),
              onDone: anyNamed('onDone'),
              cancelOnError: anyNamed('cancelOnError')))
          .thenAnswer((invocation) {
        final onData =
            invocation.positionalArguments[0] as void Function(Uint8List);
        final data = utf8.encode('{"id": 1, "message": "pong"}');
        onData(Uint8List.fromList(data));
        return Stream<Uint8List>.empty().listen(null);
      });

      await socketManager.connect('localhost', 1234, ssl: false);

      Completer completer = Completer();
      socketManager.setCompleter(1, completer);

      await socketManager.send('{"id": 1, "message": "ping"}');

      var result = await completer.future;

      expect(result, isA<Map<String, dynamic>>());
      expect(result['id'], equals(1));
      expect(result['message'], equals('pong'));
    });

    test('should handle fragmented JSON data', () async {
      // Simulate fragmented JSON data reception
      when(mockSocket.listen(any,
              onError: anyNamed('onError'),
              onDone: anyNamed('onDone'),
              cancelOnError: anyNamed('cancelOnError')))
          .thenAnswer((invocation) {
        final onData =
            invocation.positionalArguments[0] as void Function(Uint8List);
        final part1 = utf8.encode('{ "id": 1,');
        final part2 = utf8.encode('"result": {"test":[]}}');

        // Send the first part
        onData(Uint8List.fromList(part1));
        // Send the second part after a slight delay
        Future.delayed(Duration(milliseconds: 50), () {
          onData(Uint8List.fromList(part2));
        });

        return Stream<Uint8List>.empty().listen(null);
      });

      await socketManager.connect('localhost', 1234, ssl: false);

      Completer completer = Completer();
      socketManager.setCompleter(1, completer);

      // Wait for the result from the completer
      var result = await completer.future;

      // Verify the result is a valid JSON object
      expect(result, isA<Map<String, dynamic>>());
      expect(result['id'], equals(1));
      expect(result['result'], isA<Map<String, dynamic>>());
      expect(result['result']['test'], isA<List>());
    });

    test('should handle connection error', () async {
      when(mockSocket.listen(any,
              onError: anyNamed('onError'),
              onDone: anyNamed('onDone'),
              cancelOnError: anyNamed('cancelOnError')))
          .thenThrow(Error());

      await socketManager.connect('localhost', 1234, ssl: false);

      expect(
          socketManager.connectionStatus, SocketConnectionStatus.reconnecting);
    });

    test('should change to terminated state after maximum connection attempts',
        () async {
      SocketManager socketManager = SocketManager(
          factory: mockErrorSocketFactory, reconnectDelaySeconds: 0);

      await socketManager.connect('localhost', 1234, ssl: false);

      await Future.delayed(Duration(seconds: 1));

      expect(socketManager.connectionStatus, SocketConnectionStatus.terminated);
      verify(mockErrorSocketFactory.createSocket('localhost', 1234)).called(30);
    });

    test('should execute the callback function when attempting to reconnect',
        () async {
      SocketManager socketManager = SocketManager(
          factory: mockErrorSocketFactory,
          reconnectDelaySeconds: 0,
          maxConnectionAttempts: 1);

      socketManager.onReconnect = mockCallback.call;

      await socketManager.connect('localhost', 1234, ssl: false);

      await Future.delayed(Duration(seconds: 1));

      verify(mockCallback.call()).called(1);
    });

    test('should change the state to `connecting` when attempting to connect',
        () async {
      MockSocketFactory mockSocketFactory = MockSocketFactory();
      when(mockSocketFactory.createSocket('localhost', 1234))
          .thenAnswer((e) async {
        await Future.delayed(Duration(seconds: 1));
        return mockSocket;
      });
      SocketManager socketManager = SocketManager(factory: mockSocketFactory);

      socketManager.connect('localhost', 1234, ssl: false);

      await Future.delayed(Duration(milliseconds: 50));

      expect(socketManager.connectionStatus, SocketConnectionStatus.connecting);
    });
  });

  group('SocketManager SSL', () {
    late MockSecureSocket mockSecureSocket;
    late MockSocketFactory mockSocketFactory;
    late SocketManager socketManager;

    setUp(() async {
      mockSecureSocket = MockSecureSocket();
      mockSocketFactory = MockSocketFactory();
      socketManager = SocketManager(factory: mockSocketFactory);
      when(mockSocketFactory.createSecureSocket('localhost', 1234))
          .thenAnswer((e) async => mockSecureSocket);
      when(mockSecureSocket.listen(any,
              onError: anyNamed('onError'),
              onDone: anyNamed('onDone'),
              cancelOnError: anyNamed('cancelOnError')))
          .thenAnswer((invocation) =>
              StreamController<Uint8List>().stream.listen(null));
    });

    test('should connect to ssl server successfully', () async {
      await socketManager.connect('localhost', 1234, ssl: true);

      expect(socketManager.connectionStatus, SocketConnectionStatus.connected);
      verify(mockSocketFactory.createSecureSocket('localhost', 1234)).called(1);
    });
  });
}
