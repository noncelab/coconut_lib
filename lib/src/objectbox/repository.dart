part of '../../coconut_lib.dart';

///
/// Wallet Id: fingerprint + '-' + derivation path (account)
/// ex: 12345678-m/84'/1'/0'
class Repository {
  static final Repository _instance = Repository._();
  static String _directory = '';
  static bool _isInitialized = false;

  late Store _store;
  late Box<TransactionEntity> _transaction;
  late Box<UtxoEntity> _utxo;
  late Box<BalanceEntity> _balance;
  late Box<CustomIdEntity> _customId;
  late Box<AddressBookEntity> _addressBook;
  late Box<AddressEntity> _address;
  late Box<BlockHeaderEntity> _blockHeader;

  final int _gapLimit = 20;

  Repository._();

  get isClose => _instance._store.isClosed();

  static Repository initialize(String directory) {
    if (!_isInitialized || _directory != directory) {
      var store = openStore(directory: directory);

      _instance._store = store;
      _instance._transaction = store.box<TransactionEntity>();
      _instance._utxo = store.box<UtxoEntity>();
      _instance._balance = store.box<BalanceEntity>();
      _instance._customId = store.box<CustomIdEntity>();
      _instance._addressBook = store.box<AddressBookEntity>();
      _instance._address = store.box<AddressEntity>();
      _instance._blockHeader = store.box<BlockHeaderEntity>();
      _directory = directory;
      _isInitialized = true;
    }

    return _instance;
  }

  factory Repository() {
    if (!_isInitialized) {
      throw Exception(
          'Repository is not initialized yet. Call Repository.initialize() first.');
    }
    return _instance;
  }

  Balance _getBalance(int walletId) {
    BalanceEntity entity = _getBalanceEntity(walletId);

    return Balance(entity.confirmed, entity.unconfirmed);
  }

  BalanceEntity _getBalanceEntity(int walletId) {
    BalanceEntity? balanceEntity = _balance
        .query(BalanceEntity_.walletId.equals(walletId))
        .build()
        .findUnique();

    if (balanceEntity == null) {
      var newBalanceEntity =
          BalanceEntity(walletId: walletId, confirmed: 0, unconfirmed: 0);
      newBalanceEntity.id = _balance.put(newBalanceEntity);

      return newBalanceEntity;
    }

    return balanceEntity;
  }

  List<TransactionEntity> _getTransactionEntityList(WalletBase wallet,
      {int take = 5, int cursor = 0}) {
    int walletId = wallet.identifier;
    var unConfirmQuery = _transaction
        .query(TransactionEntity_.walletId
            .equals(walletId)
            .and(TransactionEntity_.height.equals(0)))
        .build();
    var confirmQuery = _transaction
        .query(TransactionEntity_.walletId
            .equals(walletId)
            .and(TransactionEntity_.height.notEquals(0)))
        .order(TransactionEntity_.height, flags: Order.descending)
        .build();

    // 언컨펌 내역 조회
    unConfirmQuery.limit = take;
    unConfirmQuery.offset = cursor;
    List<TransactionEntity> unconfirmedList = unConfirmQuery.find();

    int remaining = take - unconfirmedList.length;

    // 컨펌 내역 조회
    if (remaining > 0) {
      confirmQuery.limit = remaining;
      confirmQuery.offset = cursor;
      List<TransactionEntity> confirmedList = confirmQuery.find();

      // 언컨펌 내역과 컨펌 내역 합치기
      unconfirmedList.addAll(confirmedList);
    }

    return unconfirmedList;
  }

  List<TransactionEntity> _getFinalizedTransactionEntityList(
      WalletBase wallet) {
    int walletId = wallet.identifier;
    List<TransactionEntity> txEntityList = _transaction
        .query(TransactionEntity_.walletId
            .equals(walletId)
            .and(TransactionEntity_.height.notNull()))
        .order(TransactionEntity_.height, flags: Order.descending)
        .build()
        .find();

    return txEntityList;
  }

  List<UtxoEntity> _getUtxoEntityList(int walletId,
      {UtxoOrderEnum order = UtxoOrderEnum.byTimestampDesc}) {
    QueryProperty<UtxoEntity, dynamic> orderProperty = UtxoEntity_.timestamp;
    int sort = Order.descending;

    if (order == UtxoOrderEnum.byAmountDesc) {
      orderProperty = UtxoEntity_.amount;
    }

    List<UtxoEntity> utxoEntityList = _utxo
        .query(UtxoEntity_.walletId.equals(walletId))
        .order(orderProperty, flags: sort)
        .build()
        .find();

    return utxoEntityList;
  }

  Transaction _getTransaction(String txHash) {
    TransactionEntity txEntity = _transaction
        .query(TransactionEntity_.txHash.equals(txHash))
        .build()
        .findFirst()!;

    return txEntity.convert();
  }

  CustomIdEntity _getCustomIdEntity(String entityName, int customId) {
    var customIdEntity = _customId
        .query(CustomIdEntity_.customId.equals(customId))
        .build()
        .findUnique();

    if (customIdEntity == null) {
      var customIdEntityId =
          _customId.put(CustomIdEntity(entityName, customId));
      return _customId.get(customIdEntityId)!;
    }
    return customIdEntity;
  }

  AddressBookEntity _getAddressBookEntity(WalletBase wallet) {
    var addressBook = _addressBook
        .query(AddressBookEntity_.walletId.equals(wallet.identifier))
        .build()
        .findFirst();

    if (addressBook == null) {
      return _generateDefaultAddressBook(wallet);
    }

    return addressBook;
  }

  AddressBookEntity _generateDefaultAddressBook(WalletBase wallet) {
    var walletId = wallet.identifier;
    var addressBookEntity = AddressBookEntity(walletId: walletId);

    for (int i = 0; i < _gapLimit; i++) {
      var receiveDerivationPath = '${wallet.derivationPath}/0/$i';
      var changeDerivationPath = '${wallet.derivationPath}/1/$i';
      var receiveAddress = wallet.getAddress(i, isChange: false);
      var changeAddress = wallet.getAddress(i, isChange: true);

      var receiveAddressEntity = AddressEntity(
          address: receiveAddress,
          isUsed: false,
          derivationPath: receiveDerivationPath,
          index: i,
          amount: 0);
      var changeAddressEntity = AddressEntity(
          address: changeAddress,
          isUsed: false,
          derivationPath: changeDerivationPath,
          index: i,
          amount: 0);

      receiveAddressEntity.receiveBook.target = addressBookEntity;
      changeAddressEntity.changeBook.target = addressBookEntity;

      addressBookEntity.receiveList.add(receiveAddressEntity);
      addressBookEntity.changeList.add(changeAddressEntity);
    }
    addressBookEntity.maxReceiveIndex = _gapLimit;
    addressBookEntity.maxChangeIndex = _gapLimit;
    addressBookEntity.id = _addressBook.put(addressBookEntity);

    return addressBookEntity;
  }

  void _fillAddressBook(WalletBase wallet,
      {int from = 0, required int to, required bool isChange}) {
    var addressBookEntity = _getAddressBookEntity(wallet);
    var maxIndex = isChange
        ? addressBookEntity.maxChangeIndex
        : addressBookEntity.maxReceiveIndex;

    // 채워야할 인덱스가 이미 존재할 경우 바로 종료
    if (maxIndex >= to) {
      return;
    }

    // 채워야 할 시작 인덱스가 이미 존재하면 그 다음부터 채워지도록 수정
    if (maxIndex > from) {
      from = maxIndex;
    }

    for (int i = from; i < to; i++) {
      var derivationPath = '${wallet.derivationPath}/${isChange ? 1 : 0}/$i';
      var address = wallet.getAddress(i, isChange: isChange);

      var addressEntity = AddressEntity(
          address: address,
          isUsed: false,
          derivationPath: derivationPath,
          index: i,
          amount: 0);

      if (isChange) {
        addressEntity.changeBook.target = addressBookEntity;
        addressBookEntity.changeList.add(addressEntity);
        if (addressBookEntity.maxChangeIndex < i) {
          addressBookEntity.maxChangeIndex = i;
        }
      } else {
        addressEntity.receiveBook.target = addressBookEntity;
        addressBookEntity.receiveList.add(addressEntity);
        if (addressBookEntity.maxReceiveIndex < i) {
          addressBookEntity.maxReceiveIndex = i;
        }
      }
    }

    _addressBook.put(addressBookEntity, mode: PutMode.put);
  }

  List<Future> _getCheckUsedAddressFutures(
      WalletBase wallet, Map<int, List<int>> usedIndexList) {
    int walletId = wallet.identifier;
    var addressBookEntity = _getAddressBookEntity(wallet);

    var receiveBuilder =
        _address.query(AddressEntity_.index.oneOf(usedIndexList[0]!));
    var changeBuilder =
        _address.query(AddressEntity_.index.oneOf(usedIndexList[1]!));

    if (usedIndexList[0]!.isNotEmpty) {
      addressBookEntity.usedReceiveIndex = usedIndexList[0]!.last;
      receiveBuilder.link(AddressEntity_.receiveBook,
          AddressBookEntity_.walletId.equals(walletId));
    }

    if (usedIndexList[1]!.isNotEmpty) {
      addressBookEntity.usedChangeIndex = usedIndexList[1]!.last;
      changeBuilder.link(AddressEntity_.changeBook,
          AddressBookEntity_.walletId.equals(walletId));
    }

    List<Future> futures = [];
    var receiveAddressEntityList = receiveBuilder.build().find();
    var changeAddressEntityList = changeBuilder.build().find();

    for (var receiveEntity in receiveAddressEntityList) {
      receiveEntity.isUsed = true;
    }
    for (var changeEntity in changeAddressEntityList) {
      changeEntity.isUsed = true;
    }

    futures.add(_address.putManyAsync(
        [...receiveAddressEntityList, ...changeAddressEntityList]));
    futures.add(_addressBook.putAsync(addressBookEntity));

    return futures;
  }

  List<Future> _fillBalance(
      WalletBase wallet, Map<int, Map<int, int>> addressBalanceMap) {
    int walletId = wallet.identifier;

    List<int> receiveAddressIndexList =
        addressBalanceMap[0]!.keys.toList(growable: false);
    List<int> changeAddressIndexList =
        addressBalanceMap[1]!.keys.toList(growable: false);

    var receiveQueryBuilder =
        _address.query(AddressEntity_.index.oneOf(receiveAddressIndexList));
    var changeQueryBuilder =
        _address.query(AddressEntity_.index.oneOf(changeAddressIndexList));

    receiveQueryBuilder.link(AddressEntity_.receiveBook,
        AddressBookEntity_.walletId.equals(walletId));

    changeQueryBuilder.link(AddressEntity_.changeBook,
        AddressBookEntity_.walletId.equals(walletId));

    var receiveAddressEntityList = receiveQueryBuilder.build().find();
    var changeAddressEntityList = changeQueryBuilder.build().find();

    for (var receiveEntity in receiveAddressEntityList) {
      receiveEntity.amount = addressBalanceMap[0]![receiveEntity.index] ?? 0;
    }
    for (var changeEntity in changeAddressEntityList) {
      changeEntity.amount = addressBalanceMap[1]![changeEntity.index] ?? 0;
    }

    return [
      _address.putManyAsync(
          [...receiveAddressEntityList, ...changeAddressEntityList])
    ];
  }

  List<Address> _getAddressList(
      WalletBase wallet, int cursor, int count, bool isChange) {
    int walletId = wallet.identifier;
    var queryBuilder = _address.query().order(AddressEntity_.index);

    if (isChange) {
      queryBuilder.link(AddressEntity_.changeBook,
          AddressBookEntity_.walletId.equals(walletId));
    } else {
      queryBuilder.link(AddressEntity_.receiveBook,
          AddressBookEntity_.walletId.equals(walletId));
    }

    var query = queryBuilder.build();
    query.limit = count;
    query.offset = cursor;

    query.find();

    var list = query.find();
    return list.map((entity) => entity.toAddress()).toList();
  }

  Address? getAddress(int walletId, int index, {required bool isChange}) {
    var queryBuilder = _address.query(AddressEntity_.index.equals(index));

    if (isChange) {
      queryBuilder.link(AddressEntity_.changeBook,
          AddressBookEntity_.walletId.equals(walletId));
    } else {
      queryBuilder.link(AddressEntity_.receiveBook,
          AddressBookEntity_.walletId.equals(walletId));
    }

    return queryBuilder.build().findFirst()?.toAddress();
  }

  /// 모든 데이터 초기화, id 초기화, <ProjectRoot>/objectbox 폴더 내 파일 모두 삭제
  void resetObjectBox() {
    if (!Repository._isInitialized) {
      return;
    }
    _store.close();

    final directory = _store.directoryPath;
    final dbDirectory = Directory(directory);

    if (dbDirectory.existsSync()) {
      dbDirectory.deleteSync(recursive: true);
    }
    _store = openStore(directory: Repository._directory);
  }

  // 해당 지갑 정보만 삭제
  void resetObjectBoxWallet(WalletBase wallet) {
    var walletId = wallet.identifier;
    var addressBook = _instance._addressBook
        .query(AddressBookEntity_.walletId.equals(walletId))
        .build()
        .findFirst();
    if (addressBook != null) {
      List<int> addressIds = [];
      var changeAddressIds = _instance._address
          .query(AddressEntity_.changeBook.equals(addressBook.id))
          .build()
          .findIds();

      var receiveAddressIds = _instance._address
          .query(AddressEntity_.receiveBook.equals(addressBook.id))
          .build()
          .findIds();

      addressIds.addAll(receiveAddressIds);
      addressIds.addAll(changeAddressIds);
      _instance._addressBook.remove(addressBook.id);
      _instance._address.removeMany(addressIds);
    }
    var balanceIds = _instance._balance
        .query(BalanceEntity_.walletId.equals(walletId))
        .build()
        .findIds();

    if (balanceIds.isNotEmpty) {
      _instance._balance.removeMany(balanceIds);
    }
    var txIds = _instance._transaction
        .query(TransactionEntity_.walletId.equals(walletId))
        .build()
        .findIds();

    if (txIds.isNotEmpty) {
      _instance._transaction.removeMany(txIds);
    }
    var utxoIds = _instance._utxo
        .query(UtxoEntity_.walletId.equals(walletId))
        .build()
        .findIds();

    if (utxoIds.isNotEmpty) {
      _instance._utxo.removeMany(utxoIds);
    }
  }

  Future<void> sync(WalletBase wallet, WalletFetchResult data) async {
    resetObjectBoxWallet(wallet);

    await _saveToDatabase(wallet, data);
  }

  Future<void> _saveToDatabase(
      WalletBase wallet, WalletFetchResult electrumSync) async {
    List<Future> futures = [];
    _fillAddressBook(wallet,
        from: electrumSync.initialReceiveIndex,
        to: electrumSync.maxGapMap[0]!,
        isChange: false);

    _fillAddressBook(wallet,
        from: electrumSync.initialChangeIndex,
        to: electrumSync.maxGapMap[1]!,
        isChange: true);

    // 사용 여부 기록
    futures.addAll(
        _getCheckUsedAddressFutures(wallet, electrumSync.usedIndexList));

    if (electrumSync.txEntityList.isNotEmpty) {
      futures.addAll(
          _getSaveTxEntityListFutures(wallet, electrumSync.txEntityList));
    }

    if (electrumSync.utxoEntityList.isNotEmpty) {
      futures.addAll(_saveUtxoEntityList(electrumSync.utxoEntityList));
      futures.add(_balance.putAsync(electrumSync.balanceEntity));
      futures.addAll(_fillBalance(wallet, electrumSync.addressBalanceMap));
    }

    if (electrumSync.blockEntityMap.isNotEmpty) {
      futures.add(_blockHeader
          .putManyAsync(electrumSync.blockEntityMap.values.toList()));
    }

    await Future.wait(futures);

    // 동기화된 addressBook을 Wallet 객체에 전달
    var addressBookEntity = _getAddressBookEntity(wallet);

    wallet.addressBook = AddressBook.fromEntity(addressBookEntity);
  }

  List<Future> _getSaveTxEntityListFutures(
      WalletBase wallet, List<TransactionEntity> txEntityList) {
    // 컨펌 트랜잭션 조회
    List<TransactionEntity> savedList =
        _getFinalizedTransactionEntityList(wallet);

    // 추가+갱신된 트랜잭션
    List<TransactionEntity> entityListToPut =
        _findNewTransactions(savedList, txEntityList);

    if (entityListToPut.isNotEmpty) {
      for (var toPut in entityListToPut) {
        final txUniqueId =
            RepositoryUtil.getTxUniqueId(toPut.walletId, toPut.txHash);
        var customIdEntity =
            Repository()._getCustomIdEntity(EntityName.transaction, txUniqueId);

        toPut.id = customIdEntity.id;
      }
      return [_transaction.putManyAsync(entityListToPut, mode: PutMode.put)];
    }

    return [];
  }

  List<Future> _saveUtxoEntityList(List<UtxoEntity> utxoEntityList) {
    for (var toPut in utxoEntityList) {
      final utxoUniqueId =
          RepositoryUtil.getUtxoUniqueId(toPut.txHash, toPut.index);
      var customIdEntity = _getCustomIdEntity(EntityName.utxo, utxoUniqueId);

      toPut.id = customIdEntity.id;
    }
    return [_utxo.putManyAsync(utxoEntityList)];
  }

  /// newTxList 에서 oldTxList에 해당하는 요소들을 제외한 List 를 반환
  List<TransactionEntity> _findNewTransactions(
      List<TransactionEntity> oldTxList, List<TransactionEntity> newTxList) {
    // 두 리스트의 중복되지 않는 요소를 찾기 위한 집합 사용
    final oldSet = Set<TransactionEntity>.from(oldTxList);
    final newSet = Set<TransactionEntity>.from(newTxList);

    // 중복되지 않는 요소를 찾기 위한 차집합 연산
    return newSet.difference(oldSet).toList();
  }

  void close() {
    _isInitialized = false;
    if (!_instance.isClose) {
      _instance._store.close();
    }
  }
}
