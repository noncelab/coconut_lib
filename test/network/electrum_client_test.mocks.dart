// Mocks generated by Mockito 5.4.4 from annotations
// in coconut_lib/test/network/electrum_client_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;

import 'package:coconut_lib/coconut_lib.dart' as _i2;
import 'package:coconut_lib/src/utils/enum.dart' as _i3;
import 'package:mockito/mockito.dart' as _i1;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeSocketFactory_0 extends _i1.SmartFake implements _i2.SocketFactory {
  _FakeSocketFactory_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [SocketManager].
///
/// See the documentation for Mockito's code generation for more information.
class MockSocketManager extends _i1.Mock implements _i2.SocketManager {
  MockSocketManager() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i2.SocketFactory get socketFactory => (super.noSuchMethod(
        Invocation.getter(#socketFactory),
        returnValue: _FakeSocketFactory_0(
          this,
          Invocation.getter(#socketFactory),
        ),
      ) as _i2.SocketFactory);

  @override
  set onReconnect(void Function()? _onReconnect) => super.noSuchMethod(
        Invocation.setter(
          #onReconnect,
          _onReconnect,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i3.SocketConnectionStatus get connectionStatus => (super.noSuchMethod(
        Invocation.getter(#connectionStatus),
        returnValue: _i3.SocketConnectionStatus.reconnecting,
      ) as _i3.SocketConnectionStatus);

  @override
  dynamic setCompleter(
    int? id,
    _i4.Completer<dynamic>? completer,
  ) =>
      super.noSuchMethod(Invocation.method(
        #setCompleter,
        [
          id,
          completer,
        ],
      ));

  @override
  _i4.Future<void> connect(
    String? host,
    int? port, {
    bool? ssl = true,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #connect,
          [
            host,
            port,
          ],
          {#ssl: ssl},
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<void> disconnect() => (super.noSuchMethod(
        Invocation.method(
          #disconnect,
          [],
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<void> send(String? data) => (super.noSuchMethod(
        Invocation.method(
          #send,
          [data],
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);
}
