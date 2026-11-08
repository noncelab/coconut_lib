@Tags(['unit'])
library;

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  late SingleSignatureVault vault;
  setUp(() {
    vault = PayjoinFixture.ourVault();
  });

  group('payjoin fixtures', () {
    test('foreign inputs are finalized and carry no derivations', () {
      final Psbt psbt = PayjoinFixture.senderProposal();

      expect(psbt.inputs[1].isFinalized, isTrue);
      expect(psbt.inputs[1].witnessUtxo, isNotNull);
      expect(psbt.inputs[1].bip32Derivation, isNull);
      expect(psbt.inputs[0].isFinalized, isFalse);
      expect(psbt.inputs[2].isFinalized, isFalse);
    });

    test('final_script_sig marks an input finalized', () {
      final Map<String, dynamic> keyMap =
          PayjoinFixture.senderProposal().toKeyMap();
      keyMap['inputs'][1]
        ..remove('08')
        ..['07'] = '160014${'ab' * 20}';
      final Psbt psbt = Psbt.parse(Psbt.fromMap(keyMap).serialize());

      expect(psbt.inputs[1].finalScriptSig, '160014${'ab' * 20}');
      expect(psbt.inputs[1].isFinalized, isTrue);
    });
  });

  group('addressType', () {
    test('skips a leading foreign input', () {
      expect(PayjoinFixture.receiverProposal().addressType, AddressType.p2wpkh);
    });
  });

  group('hasPublicKeyInPsbt', () {
    test('finds our key behind a leading foreign input', () {
      final String psbt = PayjoinFixture.receiverProposal().serialize();

      expect(vault.keyStore.hasPublicKeyInPsbt(psbt), isTrue);
      expect(vault.hasPublicKeyInPsbt(psbt), isTrue);
      expect(
          PayjoinFixture.counterpartyVault().keyStore.hasPublicKeyInPsbt(psbt),
          isFalse);
    });
  });

  group('validateSingleSignaturePolicy', () {
    test('rejects foreign inputs by default', () {
      for (final Psbt psbt in [
        PayjoinFixture.senderProposal(),
        PayjoinFixture.receiverProposal()
      ]) {
        expect(
            () => psbt.validateSingleSignaturePolicy(vault),
            throwsA(isA<PsbtException>()
                .having((e) => e.code, 'code', PsbtErrorCode.missingMetadata)));
      }
    });

    test('accepts finalized foreign inputs when allowed', () {
      for (final Psbt psbt in [
        PayjoinFixture.senderProposal(),
        PayjoinFixture.receiverProposal()
      ]) {
        expect(
            () => psbt.validateSingleSignaturePolicy(vault,
                allowFinalizedForeignInputs: true),
            returnsNormally);
      }
    });

    test('accepts a finalized foreign Taproot input when allowed', () {
      final Psbt psbt = PayjoinFixture.senderProposal(
          foreignSigner: PayjoinFixture.taprootCounterpartyVault());

      expect(
          () => psbt.validateSingleSignaturePolicy(vault,
              allowFinalizedForeignInputs: true),
          returnsNormally);
    });

    test('still rejects an unfinalized input without derivations', () {
      final Map<String, dynamic> keyMap =
          PayjoinFixture.senderProposal().toKeyMap();
      keyMap['inputs'][1].remove('08');
      final Psbt psbt = Psbt.fromMap(keyMap);

      expect(
          () => psbt.validateSingleSignaturePolicy(vault,
              allowFinalizedForeignInputs: true),
          throwsA(isA<PsbtException>()
              .having((e) => e.code, 'code', PsbtErrorCode.missingMetadata)
              .having((e) => e.inputIndex, 'inputIndex', 1)));
    });

    test('checks a finalized input that claims our fingerprint', () {
      final Map<String, dynamic> keyMap =
          PayjoinFixture.senderProposal().toKeyMap();
      // A forged key under our fingerprint and path, on a finalized input.
      final String forgedKey = PayjoinFixture.counterpartyVault()
          .keyStore
          .getPublicKey(0, isChange: false);
      final String ourDerivation = (keyMap['inputs'][0] as Map<String, dynamic>)
          .entries
          .firstWhere((entry) => entry.key.startsWith('06'))
          .value;
      keyMap['inputs'][1]['06$forgedKey'] = ourDerivation;
      final Psbt psbt = Psbt.fromMap(keyMap);

      expect(
          () => psbt.validateSingleSignaturePolicy(vault,
              allowFinalizedForeignInputs: true),
          throwsA(isA<PsbtException>()
              .having((e) => e.code, 'code', PsbtErrorCode.signerMismatch)
              .having((e) => e.inputIndex, 'inputIndex', 1)));
    });

    test('checks an owned input whose witness UTXO was swapped', () {
      final Map<String, dynamic> keyMap =
          PayjoinFixture.senderProposal().toKeyMap();
      keyMap['inputs'][2]['01'] = keyMap['inputs'][1]['01'];
      final Psbt psbt = Psbt.fromMap(keyMap);

      expect(
          () => psbt.validateSingleSignaturePolicy(vault,
              allowFinalizedForeignInputs: true),
          throwsA(isA<PsbtException>()
              .having((e) => e.code, 'code', PsbtErrorCode.utxoMismatch)
              .having((e) => e.inputIndex, 'inputIndex', 2)));
    });

    test('requires at least one owned input', () {
      final SingleSignatureVault counterparty =
          PayjoinFixture.counterpartyVault();
      final Psbt psbt = PayjoinFixture.build(vault, inputs: [
        PayjoinFixture.foreignInput(counterparty, 0),
        PayjoinFixture.foreignInput(counterparty, 1),
      ], outputs: [
        OwnedOutput(150000, '${vault.derivationPath}/0/3'),
      ]);

      expect(
          () => psbt.validateSingleSignaturePolicy(vault,
              allowFinalizedForeignInputs: true),
          throwsA(isA<PsbtException>()));
    });
  });

  group('matchesVault', () {
    test('is false for foreign inputs by default and true when allowed', () {
      for (final Psbt psbt in [
        PayjoinFixture.senderProposal(),
        PayjoinFixture.receiverProposal()
      ]) {
        expect(psbt.matchesVault(vault), isFalse);
        expect(psbt.matchesVault(vault, allowFinalizedForeignInputs: true),
            isTrue);
      }
    });

    test('ignores the counterparty xpub and identifier when allowed', () {
      final SingleSignatureVault counterparty =
          PayjoinFixture.counterpartyVault();
      final Psbt psbt = PayjoinFixture.build(vault,
          inputs: [
            PayjoinFixture.foreignInput(counterparty, 0),
            OwnedInput(PayjoinFixture.ownedUtxo(vault, 0)),
          ],
          outputs: [
            OwnedOutput(150000, '${vault.derivationPath}/0/3'),
          ],
          globalsFrom: counterparty);

      expect(psbt.isFromCoconut, isTrue);
      expect(psbt.matchesVault(vault), isFalse);
      expect(
          psbt.matchesVault(vault, allowFinalizedForeignInputs: true), isTrue);
    });
  });

  group('addSignatureToPsbt', () {
    test('rejects foreign inputs by default', () {
      final String psbt = PayjoinFixture.senderProposal().serialize();

      expect(
          () => vault.addSignatureToPsbt(psbt), throwsA(isA<PsbtException>()));
      expect(() => vault.keyStore.addSignatureToPsbt(psbt, AddressType.p2wpkh),
          throwsA(isA<PsbtException>()));
    });

    for (final (String name, Psbt Function() build, List<int> owned) in [
      ('sender', PayjoinFixture.senderProposal, [0, 2]),
      ('receiver', PayjoinFixture.receiverProposal, [2]),
    ]) {
      test('signs only our inputs of the $name proposal', () {
        final Psbt unsigned = build();
        for (final String signed in [
          vault.addSignatureToPsbt(unsigned.serialize(),
              allowFinalizedForeignInputs: true),
          vault.keyStore.addSignatureToPsbt(
              unsigned.serialize(), AddressType.p2wpkh,
              allowFinalizedForeignInputs: true),
        ]) {
          final Psbt psbt = Psbt.parse(signed);
          for (int i = 0; i < psbt.inputs.length; i++) {
            if (owned.contains(i)) {
              final Signature signature = psbt.inputs[i].partialSig!.single;
              expect(
                  psbt.validateSignature(
                      i, signature.signature, signature.publicKey),
                  isTrue);
            } else {
              expect(psbt.inputs[i].partialSig, isEmpty);
              expect(psbt.inputs[i].finalScriptWitness,
                  unsigned.inputs[i].finalScriptWitness);
            }
          }
        }
      });
    }
  });

  group('isSigned', () {
    test('looks past a leading foreign input', () {
      final Psbt unsigned = PayjoinFixture.receiverProposal();
      final Psbt signed = Psbt.parse(vault.addSignatureToPsbt(
          unsigned.serialize(),
          allowFinalizedForeignInputs: true));

      expect(unsigned.isSigned(vault.keyStore), isFalse);
      expect(signed.isSigned(vault.keyStore), isTrue);
    });
  });

  group('multisignature vault', () {
    late MultisignatureVault multisig;
    late Psbt psbt;
    setUp(() {
      multisig = WalletFixture.p2wshVault();
      psbt = PayjoinFixture.build(multisig,
          inputs: [
            PayjoinFixture.foreignInput(PayjoinFixture.counterpartyVault(), 0),
            OwnedInput(PayjoinFixture.ownedUtxo(multisig, 0)),
          ],
          outputs: [
            OwnedOutput(150000, '${multisig.derivationPath}/0/3'),
            ForeignOutput(49000, UtxoFixture.receiveAddress),
          ],
          globalsFrom: multisig);
    });

    test('accepts finalized foreign inputs only when allowed', () {
      expect(psbt.matchesVault(multisig), isFalse);
      expect(psbt.matchesVault(multisig, allowFinalizedForeignInputs: true),
          isTrue);
    });

    test('signs only our inputs', () {
      expect(() => multisig.addSignatureToPsbt(psbt.serialize()),
          throwsA(isA<PsbtException>()));

      final Psbt signed = Psbt.parse(multisig.addSignatureToPsbt(
          psbt.serialize(),
          allowFinalizedForeignInputs: true));

      expect(signed.inputs[0].partialSig, isEmpty);
      expect(signed.inputs[1].partialSig, hasLength(2));
    });
  });

  group('taproot vault', () {
    late TaprootVault taproot;
    late Psbt psbt;
    setUp(() {
      taproot = WalletFixture.p2trKeyPathVault();
      psbt = PayjoinFixture.build(taproot,
          inputs: [
            OwnedInput(PayjoinFixture.ownedUtxo(taproot, 0)),
            PayjoinFixture.foreignInput(
                PayjoinFixture.taprootCounterpartyVault(), 0),
          ],
          outputs: [
            OwnedOutput(150000, '${taproot.derivationPath}/0/3'),
            ForeignOutput(49000, UtxoFixture.receiveAddress),
          ],
          globalsFrom: taproot);
    });

    test('accepts finalized foreign inputs only when allowed', () {
      expect(psbt.matchesVault(taproot), isFalse);
      expect(psbt.matchesVault(taproot, allowFinalizedForeignInputs: true),
          isTrue);
    });

    test('requires the witness UTXO of a foreign input', () {
      // BIP 341 signature hashes commit to every input's prevout.
      final Map<String, dynamic> keyMap = psbt.toKeyMap();
      keyMap['inputs'][1].remove('01');

      expect(
          () => Psbt.fromMap(keyMap).validateTaprootPolicy(taproot,
              allowFinalizedForeignInputs: true),
          throwsA(isA<PsbtException>()
              .having((e) => e.code, 'code', PsbtErrorCode.missingMetadata)
              .having((e) => e.inputIndex, 'inputIndex', 1)));
    });

    test('signs only our key-path inputs', () {
      expect(() => taproot.addSignatureToPsbt(psbt.serialize()),
          throwsA(isA<PsbtException>()));

      final Psbt signed = Psbt.parse(taproot.addSignatureToPsbt(
          psbt.serialize(),
          allowFinalizedForeignInputs: true));

      expect(signed.inputs[0].tapKeySig, isNotNull);
      expect(signed.inputs[1].tapKeySig, isNull);
      expect(signed.inputs[1].finalScriptWitness,
          psbt.inputs[1].finalScriptWitness);
    });
  });
}
