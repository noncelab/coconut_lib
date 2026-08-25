@Tags(['unit'])
library;

import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('TransactionInput', () {
    group('transactionHash', () {
      test('Get transaction hash', () {
        TransactionInput input = TransactionInput.forPayment(
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0',
            0);
        expect(input.transactionHash,
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0');
      });
    });
    group('index', () {
      test('Get index', () {
        TransactionInput input = TransactionInput.forPayment(
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0',
            0);
        expect(input.index, 0);
      });
    });
    group('sequence', () {
      test('Get sequence', () {
        TransactionInput input = TransactionInput.forPayment(
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0',
            0);
        expect(input.sequence, 4294967295);
      });
    });
    group('length', () {
      test('Get length of transaction input', () {
        TransactionInput input = TransactionInput.forPayment(
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0',
            0);
        expect(input.length, 41);
      });
    });
    group('TransactionInput.parse', () {
      test('throws on too short input', () {
        expect(() => TransactionInput.parse('0011'), throwsFormatException);
      });

      test('throws when the script length exceeds the remaining input', () {
        final input = '${'00' * 32}0100000005aabb';
        expect(() => TransactionInput.parse(input), throwsFormatException);
      });

      test('Generate transaction input from parsing on p2pkh', () {
        String inputText =
            'd06050454abde3bdd947312b9f54439acb097608a47b0b36a23d76820a3a4044000000006a4730440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be0012102742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8dfffffffff';
        TransactionInput input = TransactionInput.parse(inputText);
        expect(input.transactionHash,
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0');
        expect(input.index, 0);
        expect(input.sequence, 4294967295);
        expect(input.scriptSig.serialize(),
            '6a4730440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be0012102742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8df');
      });
      test('Generate transaction input from parsing on p2wpkh', () {
        String inputText =
            'a463a7a78daffa1bdb1248121adb14b94f70a1fabffc81637f4049c3d65cc69f000000000000000080';
        TransactionInput input = TransactionInput.parse(inputText);
        expect(input.transactionHash,
            '9fc65cd6c349407f6381fcbffaa1704fb914db1a124812db1bfaaf8da7a763a4');
        expect(input.index, 0);
        expect(input.sequence, 2147483648);
        expect(input.scriptSig.serialize(), '00');
      });

      test('Parse coinbase input', () {
        // txhash=00..00, index=ffffffff, scriptSize=2, script=abcd, sequence=ffffffff
        String inputText =
            '0000000000000000000000000000000000000000000000000000000000000000ffffffff02abcdffffffff';
        TransactionInput input = TransactionInput.parse(inputText);
        expect(input.index, 4294967295);
        expect(input.sequence, 4294967295);
        expect(input.scriptSig.commands.isNotEmpty, true);
      });
    });
    group('TransactionInput.parseForPsbt', () {
      test('Reject truncated unsigned input', () {
        expect(() => TransactionInput.parseForPsbt('00' * 40),
            throwsFormatException);
      });

      test('Generate transaction input for psbt', () {
        String inputText =
            'd06050454abde3bdd947312b9f54439acb097608a47b0b36a23d76820a3a40440000000000ffffffff';
        TransactionInput input = TransactionInput.parseForPsbt(inputText);
        expect(input.transactionHash,
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0');
        expect(input.index, 0);
        expect(input.sequence, 4294967295);
        expect(input.scriptSig.serialize(), '00');
      });
    });
    group('TransactionInput.forPayment', () {
      test('Generate transaction input for payment on p2pkh', () {
        TransactionInput input = TransactionInput.forPayment(
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0',
            0);
        expect(input, isA<TransactionInput>());
      });
      test('Generate transaction input for payment on p2wpkh', () {
        TransactionInput input = TransactionInput.forPayment(
            'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db',
            1,
            sequence: 2147483648);
        expect(input, isA<TransactionInput>());
      });
    });
    group('setSignature', () {
      test('throws when signature list is empty', () {
        TransactionInput input = TransactionInput.forPayment(
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0',
            0);
        expect(
            () => input.setSignature(AddressType.p2pkh, []), throwsException);
      });

      test('throws when multiple signatures are used in singlesig', () {
        TransactionInput input = TransactionInput.forPayment(
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0',
            0);
        expect(
            () => input.setSignature(AddressType.p2wpkh, [
                  Signature('aa', 'bb'),
                  Signature('cc', 'dd'),
                ]),
            throwsException);
      });

      test('Set signature to transaction input on p2pkh', () {
        TransactionInput input = TransactionInput.forPayment(
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0',
            0);
        input.setSignature(AddressType.p2pkh, [
          Signature(
              '30440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be001',
              '02742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8df')
        ]);
        expect(input.scriptSig.serialize(),
            '6a4730440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be0012102742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8df');
      });
      test('Set signature to transaction input on p2wpkh', () {
        TransactionInput input = TransactionInput.forPayment(
            'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db',
            1,
            sequence: 2147483648);
        input.setSignature(AddressType.p2wpkh, [
          Signature(
              '304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c092001',
              '03c0c4d5bd6ab4ad72bf4b386db12767aa0043ac1652b621afdcf3eeb299fe2fb4')
        ]);
        expect(input.scriptSig.serialize(), '00');
        expect(input.witnessList.length, 2);
        expect(input.witnessList[0],
            '304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c092001');
        expect(input.witnessList[1],
            '03c0c4d5bd6ab4ad72bf4b386db12767aa0043ac1652b621afdcf3eeb299fe2fb4');
      });

      test('Set signature to transaction input on p2wsh', () {
        TransactionInput input = TransactionInput.forPayment(
            'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db',
            1,
            sequence: 2147483648);
        List<Uint8List> publicKeys = [
          Codec.decodeHex(
              '028106e5b5449e0b78e7e06c6435f724b9797db0926ed3ba59b01d6e3dee8fd74b'),
          Codec.decodeHex(
              '02869102bed3322707dfebeaf06f9e0f89b5d133e48ee481bcd624dfc1fa1b1880'),
          Codec.decodeHex(
              '02d6481c1e9ead3f86508ec5d4b515089ae40505f642901e078824184e910d3363')
        ];
        MultisignatureScript witnessScript =
            MultisignatureScript.forP2wsh(2, 3, publicKeys);
        input.setSignature(
            AddressType.p2wsh,
            [
              Signature(
                  '304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c092001',
                  '028106e5b5449e0b78e7e06c6435f724b9797db0926ed3ba59b01d6e3dee8fd74b'),
              Signature(
                  '304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c092001',
                  '02869102bed3322707dfebeaf06f9e0f89b5d133e48ee481bcd624dfc1fa1b1880'),
            ],
            witnessScript: witnessScript);
        expect(input.scriptSig.serialize(), '00');
        expect(input.witnessList.first, '00');
        expect(input.witnessList.last, witnessScript.rawSerialize());
      });

      test('throws when p2wsh witnessScript is missing', () {
        TransactionInput input = TransactionInput.forPayment(
            'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db',
            1);
        expect(
            () =>
                input.setSignature(AddressType.p2wsh, [Signature('aa', 'bb')]),
            throwsArgumentError);
      });
    });

    group('setTaprootKeyPathSpendingSignature', () {
      test('Set taproot key path witness', () {
        TransactionInput input = TransactionInput.forPayment(
            'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db',
            1);
        input.setTaprootKeyPathSpendingSignature('aa' * 64);
        expect(input.witnessList.length, 1);
      });
    });

    group('setTaprootScriptPathSpendingSignature', () {
      test('Set taproot script path witness', () {
        TransactionInput input = TransactionInput.forPayment(
            'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db',
            1);
        input.setTaprootScriptPathSpendingSignature(
            'aa' * 64, '51', 'c0${'11' * 32}');
        expect(input.witnessList.length, 3);
      });
    });

    group('verifySpend', () {
      test('returns true on valid p2wpkh spend', () {
        final Psbt psbt = PsbtFixture.p2wpkhSigned();
        final TransactionOutput utxo = psbt.inputs[0].witnessUtxo!;
        final String sigHash =
            psbt.unsignedTransaction!.getSigHash(0, utxo, AddressType.p2wpkh);
        final Transaction signedTx =
            psbt.getSignedTransaction(AddressType.p2wpkh);
        expect(signedTx.inputs[0].verifySpend(Codec.decodeHex(sigHash), utxo),
            true);
      });

      test('returns true on valid p2wsh spend', () {
        final Psbt psbt = PsbtFixture.p2wshSigned();
        final TransactionOutput utxo = psbt.inputs[0].witnessUtxo!;
        final String witnessScript =
            psbt.inputs[0].witnessScript!.rawSerialize();
        final String sigHash = psbt.unsignedTransaction!.getSigHash(
            0, utxo, AddressType.p2wsh,
            witnessScript: witnessScript);
        final Transaction signedTx =
            psbt.getSignedTransaction(AddressType.p2wsh);
        expect(signedTx.inputs[0].verifySpend(Codec.decodeHex(sigHash), utxo),
            true);
      });

      test('returns false when a p2wsh signature is duplicated', () {
        final Psbt psbt = PsbtFixture.p2wshSigned();
        final TransactionOutput utxo = psbt.inputs[0].witnessUtxo!;
        final String witnessScript =
            psbt.inputs[0].witnessScript!.rawSerialize();
        final Uint8List sigHash = Codec.decodeHex(psbt.unsignedTransaction!
            .getSigHash(0, utxo, AddressType.p2wsh,
                witnessScript: witnessScript));
        final Transaction signedTx =
            psbt.getSignedTransaction(AddressType.p2wsh);
        final TransactionInput input = signedTx.inputs[0];
        input.witnessList[2] = input.witnessList[1];

        expect(input.verifySpend(sigHash, utxo), false);
        expect(signedTx.validateEcdsa(0, utxo, witnessScript: witnessScript),
            false);
        expect(
            signedTx.validateSpend(
                psbt.inputs.map((input) => input.witnessUtxo!).toList()),
            false);
      });

      test('returns false when p2wsh signatures are out of script order', () {
        final Psbt psbt = PsbtFixture.p2wshSigned();
        final TransactionOutput utxo = psbt.inputs[0].witnessUtxo!;
        final String witnessScript =
            psbt.inputs[0].witnessScript!.rawSerialize();
        final Uint8List sigHash = Codec.decodeHex(psbt.unsignedTransaction!
            .getSigHash(0, utxo, AddressType.p2wsh,
                witnessScript: witnessScript));
        final Transaction signedTx =
            psbt.getSignedTransaction(AddressType.p2wsh);
        final TransactionInput input = signedTx.inputs[0];
        final String firstSignature = input.witnessList[1];
        input.witnessList[1] = input.witnessList[2];
        input.witnessList[2] = firstSignature;

        expect(input.verifySpend(sigHash, utxo), false);
      });

      test('returns false on a non-empty p2wsh dummy witness item', () {
        final Psbt psbt = PsbtFixture.p2wshSigned();
        final TransactionOutput utxo = psbt.inputs[0].witnessUtxo!;
        final String witnessScript =
            psbt.inputs[0].witnessScript!.rawSerialize();
        final Uint8List sigHash = Codec.decodeHex(psbt.unsignedTransaction!
            .getSigHash(0, utxo, AddressType.p2wsh,
                witnessScript: witnessScript));
        final Transaction signedTx =
            psbt.getSignedTransaction(AddressType.p2wsh);
        signedTx.inputs[0].witnessList[0] = '01';

        expect(signedTx.inputs[0].verifySpend(sigHash, utxo), false);
      });

      test('returns false on malformed p2wsh witness structures', () {
        final Psbt psbt = PsbtFixture.p2wshSigned();
        final TransactionOutput utxo = psbt.inputs[0].witnessUtxo!;
        final String witnessScript =
            psbt.inputs[0].witnessScript!.rawSerialize();
        final Uint8List sigHash = Codec.decodeHex(psbt.unsignedTransaction!
            .getSigHash(0, utxo, AddressType.p2wsh,
                witnessScript: witnessScript));
        final Transaction signedTx =
            psbt.getSignedTransaction(AddressType.p2wsh);
        final TransactionInput input = signedTx.inputs[0];
        final List<String> validWitness = List<String>.from(input.witnessList);

        input.witnessList = ['00', witnessScript];
        expect(input.verifySpend(sigHash, utxo), false);

        input.witnessList = List<String>.from(validWitness)
          ..insert(validWitness.length - 1, validWitness[1]);
        expect(input.verifySpend(sigHash, utxo), false);

        input.witnessList = List<String>.from(validWitness);
        input.witnessList.last = 'zz';
        expect(input.verifySpend(sigHash, utxo), false);
        expect(signedTx.validateEcdsa(0, utxo), false);
      });

      test('returns false on an unsupported p2wsh sighash type', () {
        final Psbt psbt = PsbtFixture.p2wshSigned();
        final TransactionOutput utxo = psbt.inputs[0].witnessUtxo!;
        final String witnessScript =
            psbt.inputs[0].witnessScript!.rawSerialize();
        final Uint8List sigHash = Codec.decodeHex(psbt.unsignedTransaction!
            .getSigHash(0, utxo, AddressType.p2wsh,
                witnessScript: witnessScript));
        final Transaction signedTx =
            psbt.getSignedTransaction(AddressType.p2wsh);
        final TransactionInput input = signedTx.inputs[0];
        input.witnessList[1] =
            '${input.witnessList[1].substring(0, input.witnessList[1].length - 2)}02';

        expect(input.verifySpend(sigHash, utxo), false);
      });

      test('returns false on malformed p2wsh DER signatures', () {
        final Psbt psbt = PsbtFixture.p2wshSigned();
        final TransactionOutput utxo = psbt.inputs[0].witnessUtxo!;
        final String witnessScript =
            psbt.inputs[0].witnessScript!.rawSerialize();
        final Uint8List sigHash = Codec.decodeHex(psbt.unsignedTransaction!
            .getSigHash(0, utxo, AddressType.p2wsh,
                witnessScript: witnessScript));
        final Transaction signedTx =
            psbt.getSignedTransaction(AddressType.p2wsh);

        const malformedSignatures = [
          '30', // truncated sequence
          '310602010102010101', // wrong sequence tag
          '300602018002010101', // negative R
          '30070202000102010101', // non-minimal R
          '300602010102020101', // inconsistent S length
        ];

        for (final signature in malformedSignatures) {
          final input = signedTx.inputs[0];
          final originalSignature = input.witnessList[1];
          input.witnessList[1] = signature;
          expect(input.verifySpend(sigHash, utxo), false);
          input.witnessList[1] = originalSignature;
        }
      });

      test('returns true on valid taproot key-path spend', () {
        final Psbt psbt = PsbtFixture.p2trKeyPathSigned();
        final TransactionOutput utxo = psbt.inputs[0].witnessUtxo!;
        final List<TransactionOutput> utxos = [utxo];
        final String sigHash =
            psbt.unsignedTransaction!.getTaprootSigHash(0, utxos);
        final Transaction signedTx =
            psbt.getSignedTransaction(AddressType.p2tr);
        expect(signedTx.inputs[0].verifySpend(Codec.decodeHex(sigHash), utxo),
            true);
      });

      test('returns false on p2wpkh pubkey-hash mismatch', () {
        TransactionInput input = TransactionInput.forPayment(
            'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db',
            1);
        input.witnessList = [
          '304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c092001',
          '03c0c4d5bd6ab4ad72bf4b386db12767aa0043ac1652b621afdcf3eeb299fe2fb4'
        ];
        // hash160(pubkey) != script program below
        TransactionOutput utxo = TransactionOutput.parse(
            'a0860100000000001600140000000000000000000000000000000000000000');
        expect(input.verifySpend(Uint8List(32), utxo), false);
      });

      test('returns false on p2wsh script-hash mismatch', () {
        TransactionInput input = TransactionInput.forPayment(
            'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db',
            1);
        input.witnessList = [
          '00',
          '304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c092001',
          '5221028106e5b5449e0b78e7e06c6435f724b9797db0926ed3ba59b01d6e3dee8fd74b2102869102bed3322707dfebeaf06f9e0f89b5d133e48ee481bcd624dfc1fa1b188052ae'
        ];
        TransactionOutput utxo =
            TransactionOutput.parse('a086010000000000220020${'00' * 32}');
        expect(input.verifySpend(Uint8List(32), utxo), false);
      });

      test(
          'returns false on taproot script path with invalid control block size',
          () {
        TransactionInput input = TransactionInput.forPayment(
            'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db',
            1);
        input.witnessList = ['11' * 64, '51', 'c0']; // too short control block
        TransactionOutput utxo =
            TransactionOutput.parse('a086010000000000225120${'11' * 32}');
        expect(input.verifySpend(Uint8List(32), utxo), false);
      });

      test('throws on unsupported address type', () {
        TransactionInput input = TransactionInput.forPayment(
            'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db',
            1);
        TransactionOutput utxo = TransactionOutput.parse(
            'a0860100000000001976a914000000000000000000000000000000000000000088ac');
        expect(() => input.verifySpend(Uint8List(32), utxo), throwsException);
      });
    });
    group('hasSignature', () {
      test('Check the transaction input has signature on p2pkh', () {
        TransactionInput input = TransactionInput.forPayment(
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0',
            0);
        expect(input.hasSignature(false), false);
        input.setSignature(AddressType.p2pkh, [
          Signature(
              '30440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be001',
              '02742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8df')
        ]);
        expect(input.hasSignature(false), true);
      });
      test('Check the transaction input has signature on p2wpkh', () {
        TransactionInput input = TransactionInput.forPayment(
            'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db',
            1,
            sequence: 2147483648);
        expect(input.hasSignature(true), false);
        input.setSignature(AddressType.p2wpkh, [
          Signature(
              '304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c092001',
              '03c0c4d5bd6ab4ad72bf4b386db12767aa0043ac1652b621afdcf3eeb299fe2fb4')
        ]);
        expect(input.hasSignature(true), true);
      });
    });
    group('serialize', () {
      test('Serialize transaction input on p2pkh ', () {
        TransactionInput input = TransactionInput.forPayment(
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0',
            0);
        input.setSignature(AddressType.p2pkh, [
          Signature(
              '30440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be001',
              '02742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8df')
        ]);
        expect(input.serialize(),
            'd06050454abde3bdd947312b9f54439acb097608a47b0b36a23d76820a3a4044000000006a4730440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be0012102742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8dfffffffff');
      });
      test('Serialize transaction input on p2wpkh ', () {
        TransactionInput input = TransactionInput.forPayment(
            'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db',
            1,
            sequence: 2147483648);
        input.setSignature(AddressType.p2wpkh, [
          Signature(
              '304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c092001',
              '03c0c4d5bd6ab4ad72bf4b386db12767aa0043ac1652b621afdcf3eeb299fe2fb4')
        ]);
        expect(input.serialize(),
            'db01d2e05c8d032d2f3b54b7322e11dc408789e04960e01d4683cd57c7b970a7010000000000000080');
      });
    });
  });
}
