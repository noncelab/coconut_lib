// Mocks generated by Mockito 5.4.4 from annotations
// in coconut_lib/test/network/node_connector_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i6;

import 'package:coconut_lib/coconut_lib.dart' as _i2;
import 'package:coconut_lib/src/network/electrum/electrum_response_types.dart'
    as _i8;
import 'package:coconut_lib/src/utils/enum.dart' as _i5;
import 'package:coconut_lib/src/utils/error.dart' as _i7;
import 'package:coconut_lib/src/utils/result_type.dart' as _i3;
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

class _FakeBlock_0 extends _i1.SmartFake implements _i2.BlockTimestamp {
  _FakeBlock_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeResult_1<T, E> extends _i1.SmartFake implements _i3.Result<T, E> {
  _FakeResult_1(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

// class _FakeBlockHeaderEntity_2 extends _i1.SmartFake
//     implements _i4.BlockHeaderEntity {
//   _FakeBlockHeaderEntity_2(
//     Object parent,
//     Invocation parentInvocation,
//   ) : super(
//           parent,
//           parentInvocation,
//         );
// }

/// A class which mocks [ElectrumApi].
///
/// See the documentation for Mockito's code generation for more information.
class MockElectrumApi extends _i1.Mock implements _i2.ElectrumApi {
  MockElectrumApi() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i5.SocketConnectionStatus get connectionStatus => (super.noSuchMethod(
        Invocation.getter(#connectionStatus),
        returnValue: _i5.SocketConnectionStatus.reconnecting,
      ) as _i5.SocketConnectionStatus);

  @override
  int get reqId => (super.noSuchMethod(
        Invocation.getter(#reqId),
        returnValue: 0,
      ) as int);

  @override
  _i2.BlockTimestamp get block => (super.noSuchMethod(
        Invocation.getter(#block),
        returnValue: _FakeBlock_0(
          this,
          Invocation.getter(#block),
        ),
      ) as _i2.BlockTimestamp);

  @override
  int get gapLimit => (super.noSuchMethod(
        Invocation.getter(#gapLimit),
        returnValue: 0,
      ) as int);

  @override
  _i6.Future<_i3.Result<String, _i7.CoconutError>> broadcast(
          String? rawTransaction) =>
      (super.noSuchMethod(
        Invocation.method(
          #broadcast,
          [rawTransaction],
        ),
        returnValue: _i6.Future<_i3.Result<String, _i7.CoconutError>>.value(
            _FakeResult_1<String, _i7.CoconutError>(
          this,
          Invocation.method(
            #broadcast,
            [rawTransaction],
          ),
        )),
      ) as _i6.Future<_i3.Result<String, _i7.CoconutError>>);

  @override
  _i6.Future<_i3.Result<_i2.WalletStatus, _i7.CoconutError>> fullSync(
          _i2.WalletBase? wallet) =>
      (super.noSuchMethod(
        Invocation.method(
          #fullSync,
          [wallet],
        ),
        returnValue:
            _i6.Future<_i3.Result<_i2.WalletStatus, _i7.CoconutError>>.value(
                _FakeResult_1<_i2.WalletStatus, _i7.CoconutError>(
          this,
          Invocation.method(
            #fullSync,
            [wallet],
          ),
        )),
      ) as _i6.Future<_i3.Result<_i2.WalletStatus, _i7.CoconutError>>);

  @override
  _i6.Future<_i3.Result<int, _i7.CoconutError>> getNetworkMinimumFeeRate() =>
      (super.noSuchMethod(
        Invocation.method(
          #getNetworkMinimumFeeRate,
          [],
        ),
        returnValue: _i6.Future<_i3.Result<int, _i7.CoconutError>>.value(
            _FakeResult_1<int, _i7.CoconutError>(
          this,
          Invocation.method(
            #getNetworkMinimumFeeRate,
            [],
          ),
        )),
      ) as _i6.Future<_i3.Result<int, _i7.CoconutError>>);

  @override
  void fetchBlock() => super.noSuchMethod(
        Invocation.method(
          #fetchBlock,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i6.Future<_i2.BlockTimestamp> fetchBlockSync() => (super.noSuchMethod(
        Invocation.method(
          #fetchBlockSync,
          [],
        ),
        returnValue: _i6.Future<_i2.BlockTimestamp>.value(_FakeBlock_0(
          this,
          Invocation.method(
            #fetchBlockSync,
            [],
          ),
        )),
      ) as _i6.Future<_i2.BlockTimestamp>);

  // @override
  // _i6.Future<_i4.BlockHeaderEntity> getCurrentBlock() => (super.noSuchMethod(
  //       Invocation.method(
  //         #getCurrentBlock,
  //         [],
  //       ),
  //       returnValue:
  //           _i6.Future<_i4.BlockHeaderEntity>.value(_FakeBlockHeaderEntity_2(
  //         this,
  //         Invocation.method(
  //           #getCurrentBlock,
  //           [],
  //         ),
  //       )),
  //     ) as _i6.Future<_i4.BlockHeaderEntity>);

  @override
  _i6.Future<_i3.Result<String, _i7.CoconutError>> getTransaction(
          String? txHash) =>
      (super.noSuchMethod(
        Invocation.method(
          #getTransaction,
          [txHash],
        ),
        returnValue: _i6.Future<_i3.Result<String, _i7.CoconutError>>.value(
            _FakeResult_1<String, _i7.CoconutError>(
          this,
          Invocation.method(
            #getTransaction,
            [txHash],
          ),
        )),
      ) as _i6.Future<_i3.Result<String, _i7.CoconutError>>);

  @override
  _i6.Future<void> fetchTxHistory(
    Set<_i8.GetHistoryRes>? txHistorySet,
    _i2.WalletBase? wallet,
    bool? isChange,
    Map<int, int>? maxGapMap,
    Set<int>? toFetchBlockHeightSet,
    Map<int, List<int>>? usedIndexList, {
    int? initialIndex = 0,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #fetchTxHistory,
          [
            txHistorySet,
            wallet,
            isChange,
            maxGapMap,
            toFetchBlockHeightSet,
            usedIndexList,
          ],
          {#initialIndex: initialIndex},
        ),
        returnValue: _i6.Future<void>.value(),
        returnValueForMissingStub: _i6.Future<void>.value(),
      ) as _i6.Future<void>);

  @override
  _i6.Future<void> close() => (super.noSuchMethod(
        Invocation.method(
          #close,
          [],
        ),
        returnValue: _i6.Future<void>.value(),
        returnValueForMissingStub: _i6.Future<void>.value(),
      ) as _i6.Future<void>);
}
