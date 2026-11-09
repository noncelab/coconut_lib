import 'package:coconut_lib/coconut_lib.dart';

import 'utxo_fixture.dart';
import 'wallet_fixture.dart';

/// An input of a payjoin PSBT, in transaction order.
sealed class PayjoinInput {
  final Utxo utxo;
  const PayjoinInput(this.utxo);
}

/// An input of the wallet under test: unsigned, with its derivation metadata.
final class OwnedInput extends PayjoinInput {
  const OwnedInput(super.utxo);
}

/// The counterparty's input: finalized with a valid witness, no derivations.
final class ForeignInput extends PayjoinInput {
  final WalletBase signer;
  const ForeignInput(super.utxo, this.signer);
}

sealed class PayjoinOutput {
  final int amount;
  const PayjoinOutput(this.amount);
}

/// An output paying the wallet under test, with its derivation metadata.
final class OwnedOutput extends PayjoinOutput {
  final String derivationPath;
  const OwnedOutput(super.amount, this.derivationPath);
}

final class ForeignOutput extends PayjoinOutput {
  final String address;
  const ForeignOutput(super.amount, this.address);
}

/// Builds payjoin-shaped PSBTs: some inputs belong to the wallet under test,
/// the rest are the counterparty's, already signed and finalized.
abstract final class PayjoinFixture {
  static SingleSignatureVault ourVault() => WalletFixture.p2wpkhVault();

  static SingleSignatureVault counterpartyVault() =>
      WalletFixture.p2wpkhVault(passphrase: 'counterparty');

  static TaprootVault taprootCounterpartyVault() =>
      WalletFixture.p2trKeyPathVault(passphrase: 'counterparty');

  static Utxo ownedUtxo(WalletBase vault, int index, {int amount = 100000}) =>
      UtxoFixture.create(
          amount: amount,
          derivationPath: '${vault.derivationPath}/0/$index',
          entropy: 'owned ${vault.descriptor} #$index');

  static ForeignInput foreignInput(WalletBase signer, int index,
          {int amount = 100000}) =>
      ForeignInput(
          UtxoFixture.create(
              amount: amount,
              derivationPath: '${signer.derivationPath}/0/$index',
              entropy: 'foreign ${signer.descriptor} #$index'),
          signer);

  /// Sender's view of a proposal: two of our inputs unsigned, the receiver's
  /// input finalized between them, the receiver's output bumped by its input.
  static Psbt senderProposal({WalletBase? foreignSigner}) {
    final vault = ourVault();
    final WalletBase signer = foreignSigner ?? counterpartyVault();
    return build(vault, inputs: [
      OwnedInput(ownedUtxo(vault, 0)),
      foreignInput(signer, 0),
      OwnedInput(ownedUtxo(vault, 1)),
    ], outputs: [
      ForeignOutput(150000, signer.getAddress(5)),
      OwnedOutput(149000, '${vault.derivationPath}/1/1'),
    ]);
  }

  /// Receiver's view: the sender's two inputs finalized, one of ours
  /// unsigned, our output receiving the transfer plus our input.
  static Psbt receiverProposal() {
    final vault = ourVault();
    final signer = counterpartyVault();
    return build(vault, inputs: [
      foreignInput(signer, 0),
      foreignInput(signer, 1),
      OwnedInput(ownedUtxo(vault, 0)),
    ], outputs: [
      ForeignOutput(99000, signer.getAddress(1, isChange: true)),
      OwnedOutput(200000, '${vault.derivationPath}/0/7'),
    ]);
  }

  /// Assembles the PSBT and signs and finalizes every [ForeignInput] over the
  /// final transaction, so the foreign witnesses are valid.
  static Psbt build(WalletBase vault,
      {required List<PayjoinInput> inputs,
      required List<PayjoinOutput> outputs,
      WalletBase? globalsFrom}) {
    final List<TransactionOutput> prevouts = inputs
        .map((input) => TransactionOutput.forPayment(
            input.utxo.amount,
            (input is ForeignInput ? input.signer : vault)
                .getAddressWithDerivationPath(input.utxo.derivationPath)))
        .toList();
    final Transaction tx = Transaction.withInputsAndOutputs(
        inputs
            .map((input) => TransactionInput.forPayment(
                input.utxo.transactionHash, input.utxo.index))
            .toList(),
        outputs
            .map((output) => TransactionOutput.forPayment(
                output.amount,
                switch (output) {
                  OwnedOutput(:final derivationPath) =>
                    vault.getAddressWithDerivationPath(derivationPath),
                  ForeignOutput(:final address) => address,
                }))
            .toList(),
        // Legacy serialization, as PSBT_GLOBAL_UNSIGNED_TX requires.
        AddressType.p2pkh);

    final Map<String, dynamic> globals = {'00': tx.serialize()};
    if (globalsFrom != null) {
      final Map<String, dynamic> walletGlobals = Map.from(
          _ownedPsbt(globalsFrom, ownedUtxo(globalsFrom, 0))
              .toKeyMap()['global']);
      globals.addAll(walletGlobals..remove('00'));
    }
    final List<Map<String, dynamic>> inputMaps = [];
    for (int i = 0; i < inputs.length; i++) {
      final PayjoinInput input = inputs[i];
      switch (input) {
        case OwnedInput():
          inputMaps.add(Map<String, dynamic>.from(
              _ownedPsbt(vault, input.utxo).toKeyMap()['inputs'][0]));
        case ForeignInput():
          inputMaps.add({
            '01': prevouts[i].serialize(),
            '08': serializeWitness(_foreignWitness(tx, i, input, prevouts)),
          });
      }
    }
    final List<Map<String, dynamic>> outputMaps = outputs
        .map((output) => switch (output) {
              OwnedOutput(:final derivationPath) => Map<String, dynamic>.from(
                  _ownedPsbt(vault, ownedUtxo(vault, 0),
                          changePath: derivationPath)
                      .toKeyMap()['outputs'][1]),
              ForeignOutput() => <String, dynamic>{},
            })
        .toList();

    final Psbt psbt = Psbt.fromMap(
        {'global': globals, 'inputs': inputMaps, 'outputs': outputMaps});
    return Psbt.parse(psbt.serialize());
  }

  /// The proposal a payjoin sender gets back for [original], as rust-payjoin
  /// hands it over: the receiver inserts [input] at [inputIndex] and adds
  /// its amount less [receiverFee] to output [outputIndex], clearing the
  /// sender's signatures; the sender then restores its inputs' and outputs'
  /// metadata from [original].
  static Psbt receiverContribution(Psbt original, ForeignInput input,
      {required int inputIndex,
      required int outputIndex,
      int receiverFee = 0}) {
    final Transaction originalTx = original.unsignedTransaction!;
    final List<TransactionInput> txInputs = [
      ...originalTx.inputs.map((txInput) =>
          TransactionInput.forPayment(txInput.transactionHash, txInput.index))
    ]..insert(
        inputIndex,
        TransactionInput.forPayment(
            input.utxo.transactionHash, input.utxo.index));
    final List<TransactionOutput> txOutputs = [
      for (int i = 0; i < originalTx.outputs.length; i++)
        TransactionOutput.forPayment(
            originalTx.outputs[i].amount +
                (i == outputIndex ? input.utxo.amount - receiverFee : 0),
            originalTx.outputs[i].scriptPubKey.getAddress())
    ];
    final Transaction tx = Transaction.withInputsAndOutputs(
        txInputs, txOutputs, AddressType.p2pkh);

    final List<TransactionOutput> prevouts = [
      ...original.inputs.map((psbtInput) => psbtInput.witnessUtxo!)
    ]..insert(
        inputIndex,
        TransactionOutput.forPayment(
            input.utxo.amount,
            input.signer
                .getAddressWithDerivationPath(input.utxo.derivationPath)));
    final Map<String, dynamic> originalMap = original.toKeyMap();
    final List<Map<String, dynamic>> inputMaps = [
      for (final Map<String, dynamic> inputMap in originalMap['inputs'])
        Map<String, dynamic>.from(inputMap)
          ..removeWhere(
              (key, _) => key == '07' || key == '08' || key.startsWith('02'))
    ]..insert(inputIndex, {
        '01': prevouts[inputIndex].serialize(),
        '08':
            serializeWitness(_foreignWitness(tx, inputIndex, input, prevouts)),
      });
    final Psbt psbt = Psbt.fromMap({
      'global': {'00': tx.serialize()},
      'inputs': inputMaps,
      'outputs': [
        for (final Map<String, dynamic> outputMap in originalMap['outputs'])
          Map<String, dynamic>.from(outputMap)
      ],
    });
    return Psbt.parse(psbt.serialize());
  }

  /// BIP 141 witness stack serialization, as stored in a PSBT.
  static String serializeWitness(List<String> items) {
    final StringBuffer buffer = StringBuffer(
        Codec.encodeHex(Codec.encodeVariableInteger(items.length)));
    for (final String item in items) {
      buffer
        ..write(Codec.encodeHex(Codec.encodeVariableInteger(item.length ~/ 2)))
        ..write(item);
    }
    return buffer.toString();
  }

  static List<String> _foreignWitness(Transaction tx, int index,
      ForeignInput input, List<TransactionOutput> prevouts) {
    final String path = input.utxo.derivationPath;
    final int addressIndex =
        WalletUtility.getAccountIndexFromDerivationPath(path);
    final bool isChange = WalletUtility.isChangeFromDerivationPath(path);
    final WalletBase signer = input.signer;
    if (signer is SingleSignatureVault) {
      final KeyStore keyStore = signer.keyStore;
      final String publicKey =
          keyStore.getPublicKey(addressIndex, isChange: isChange);
      final PsbtInput psbtInput = PsbtInput.forSegwit(prevouts[index],
          [DerivationPath(publicKey, keyStore.masterFingerprint, path)], []);
      keyStore.addSignatureToPsbtInput(psbtInput, AddressType.p2wpkh, path,
          tx.getSigHash(index, prevouts[index], AddressType.p2wpkh));
      return [psbtInput.partialSig!.single.signature, publicKey];
    }
    if (signer is TaprootVault) {
      final KeyStore keyStore = signer.keyStoreList.single;
      final PsbtInput psbtInput =
          PsbtInput.forKeyPathSpending(null, prevouts[index], [], null);
      keyStore.addSignatureToPsbtInput(psbtInput, AddressType.p2tr, path,
          tx.getTaprootSigHash(index, prevouts));
      return [psbtInput.tapKeySig!];
    }
    throw UnsupportedError('Unsupported counterparty: ${signer.runtimeType}');
  }

  static Psbt _ownedPsbt(WalletBase vault, Utxo utxo, {String? changePath}) {
    final Transaction tx = Transaction.forSinglePayment(
        [utxo],
        UtxoFixture.receiveAddress,
        changePath ?? '${vault.derivationPath}/1/0',
        1000,
        1,
        vault);
    return Psbt.fromTransaction(tx, vault);
  }
}
