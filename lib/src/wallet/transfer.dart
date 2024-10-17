part of '../../coconut_lib.dart';

/// Represents a transfer information in a wallet.
class Transfer {
  final String _transactionHash;
  final DateTime? _timestamp;
  final int? _blockHeight;
  final String? _transferType;
  final String? _memo;
  final int? _amount;
  final int? _fee;
  final List<String> _inputAddressList;
  final List<String> _outputAddressList;

  /// Get the transaction hash of this transfer.
  String get transactionHash => _transactionHash;

  /// Get the timestamp of this transfer.
  DateTime? get timestamp => _timestamp;

  /// Get the block height of this transfer.
  int? get blockHeight => _blockHeight;

  /// Get the transfer type of this transfer. (RECEIVED, SEND, SELF, UNKNOWN)
  String? get transferType => _transferType;

  /// Get the memo of this transfer.
  String? get memo => _memo;

  /// Get the amount of this transfer.
  int? get amount => _amount;

  /// Get the fee of this transfer.
  int? get fee => _fee;

  /// Get the input address list of this transfer.
  List<String> get inputAddressList => _inputAddressList;

  /// Get the output address list of this transfer.
  List<String> get outputAddressList => _outputAddressList;

  /// @nodoc
  Transfer(
      this._transactionHash,
      this._timestamp,
      this._blockHeight,
      this._transferType,
      this._memo,
      this._amount,
      this._fee,
      this._inputAddressList,
      this._outputAddressList);

  /// @nodoc
  factory Transfer.fromTransactions(
      AddressBook addressBook, Transaction transaction) {
    var timestamp =
        DateTime.fromMillisecondsSinceEpoch(transaction.timestamp * 1000);
    var tx = Transaction.parse(transaction.serialize());

    int amount = 0;
    int fee = 0;
    List<String> inputAddressList = [];
    List<String> outputAddressList = [];
    int selfInputCount = 0;
    int selfOutputCount = 0;

    for (int i = 0; i < tx.inputs.length; ++i) {
      var input = tx.inputs[i];
      var inputTx = transaction.perviousTransactionList[i];
      var inputTxOutput = inputTx.outputs[input.index];

      String inputAddress = inputTxOutput.getAddress();
      inputAddressList.add(inputAddress);
      fee += inputTxOutput.amount;
      if (addressBook.contains(inputAddress)) {
        selfInputCount++;
        amount -= inputTxOutput.amount;
      }
    }

    for (var output in tx.outputs) {
      String outputAddress = output.getAddress();
      outputAddressList.add(outputAddress);
      fee -= output.amount;
      if (addressBook.contains(outputAddress)) {
        selfOutputCount++;
        amount += output.amount;
      }
    }

    TransactionTypeEnum txType;
    if (selfInputCount > 0 &&
        selfOutputCount == tx.outputs.length &&
        selfInputCount == tx.inputs.length) {
      txType = TransactionTypeEnum.self;
    } else if (selfInputCount > 0 && selfOutputCount < tx.outputs.length) {
      txType = TransactionTypeEnum.sent;
    } else {
      txType = TransactionTypeEnum.received;
    }

    return Transfer(
      transaction.transactionHash,
      timestamp,
      transaction.height,
      txType.name,
      transaction.memo,
      amount,
      fee,
      inputAddressList,
      outputAddressList,
    );
  }
}
