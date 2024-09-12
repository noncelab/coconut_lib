@Tags(['integration'])
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_lib/src/utils/converter.dart';
import 'package:coconut_lib/src/utils/hash.dart';
import 'package:test/test.dart';

main() async {
  String dbDirectory = 'objectbox';
  Repository.initialize(dbDirectory);
  BitcoinNetwork.setNetwork(BitcoinNetwork.testnet);
  NodeConnector nodeConnector =
      await NodeConnector.connectSync('blockstream.info', 143, ssl: false);

  group('Script Test', () {
    test('p2wpkh test', () {
      String address = 'bc1q8308eecs36wqlkyytnqjf6nq6v9xxh54wt3fj8';
      ScriptPublicKey scriptPubKey = ScriptPublicKey.p2wpkh(address);
      String result = scriptPubKey.serialize();
      expect(result, '1600143c5e7ce7108e9c0fd8845cc124ea60d30a635e95');
    });

    test('p2wpkh get address test', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.testnet);
      String script = '160014cb325c29ac1d9f9c56ab77c7f659f6a304a7bd02';
      ScriptPublicKey scriptPubKey = ScriptPublicKey.parse(script);
      String address = scriptPubKey.getAddress();
      expect(address, 'tb1qeve9c2dvrk0ec44twlrlvk0k5vz200gz8pu2wn');
    });

    test('p2tr get address test', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.testnet);
      String scriptPubKey =
          '22512028d00add401c7cacf799aa43d074972518c7dcc02c6bac140316707096c38510';
      ScriptPublicKey script = ScriptPublicKey.parse(scriptPubKey);
      print(script.getAddress());
      expect(script.getAddress(),
          'tb1p9rgq4h2qr372eaue4fpaqayhy5vv0hxq9346c9qrzec8p9krs5gqfj6h0c');
    });

    test('p2sh get address test', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      String scriptPubKey = '17a91414a6d9f1ce6e5392df68e987de44b303525cc08687';
      ScriptPublicKey script = ScriptPublicKey.parse(scriptPubKey);

      expect(script.getAddress(), '33aDKR2hrf3UP4FZKuSAdDB6v9wpfDVRSs');
    });

    test('p2wsh get address test', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      String scriptPubKey =
          '2200200d03b386199fc909ca35652f582a526c6b1c45a588d0843759915eb6a41528b7';
      ScriptPublicKey script = ScriptPublicKey.parse(scriptPubKey);

      expect(script.getAddress(),
          'bc1qp5pm8psenlysnj34v5h4s2jjd343c3d93rgggd6ej90tdfq49zmsdcjk0c');
    });
  });

  group('Transaction test', () {
    test('test P2WPKH address', () {
      ScriptPublicKey outputScript1 = (ScriptPublicKey.parse(
          '160014b247a00acc1cc2c0b4be0d3c38d866f9c08d244a'));
      String expectedOutputAddress1 =
          'bc1qkfr6qzkvrnpvpd97p57r3krxl8qg6fz24nzjsa';
      expect(outputScript1.getAddress(), expectedOutputAddress1);

      ScriptPublicKey outputScript2 = ScriptPublicKey.parse(
          '160014d32c7c4dbb9457cff124c786bac87a9a706c5b3a');
      String expectedOutputAddress2 =
          'bc1q6vk8cndmj3tulufyc7rt4jr6nfcxcke6f42j0n';
      expect(outputScript2.getAddress(), expectedOutputAddress2);
    });

    test('test P2PKH address', () {
      ScriptPublicKey outputScript1 = ScriptPublicKey.parse(
          '1976a914c25ae3a6ea9d9d639f1e7c78edeb522629e51dfa88ac');
      String expectedOutputAddress1 = '1JieyK6YYufbwwcMMm7rB31QJcLQEphpTA';
      expect(outputScript1.getAddress(), expectedOutputAddress1);
    });

    test('Ouput parse and serialize (segwit)', () {
      String outputString =
          'e803000000000000160014b247a00acc1cc2c0b4be0d3c38d866f9c08d244a';
      TransactionOutput output = TransactionOutput.parse(outputString);
      //print('in parse : ' + output.scriptPubKey.cmds.toString());
      expect(output.amount, 1000);
      //print(output.scriptPubKey.commands.toString());
      expect(output.scriptPubKey.getAddress(),
          'bc1qkfr6qzkvrnpvpd97p57r3krxl8qg6fz24nzjsa');
      expect(output.serialize(), outputString);

      //legacy
    });

    test('Ouput parse and serialize (legacy)', () {
      String outputString =
          '277c5d000000000016001424b3e9491f3eadd9862389d98480acf89bdab078';
      TransactionOutput output = TransactionOutput.parse(outputString);
      //print('in parse : ' + output.scriptPubKey.cmds.toString());
      //print('amount : ' + output.amount.toString());
      expect(output.amount, 6126631);
      //print(output.scriptPubKey.commands.toString());
      expect(output.scriptPubKey.getAddress(),
          'bc1qyje7jjgl86kanp3r38vcfq9vlzda4vrccprts0');
      expect(output.serialize(), outputString);

      //legacy
    });

    test('Ouput for sending(p2wpkh)', () {
      String address = 'bc1qkfr6qzkvrnpvpd97p57r3krxl8qg6fz24nzjsa';
      int amount = 1000;
      TransactionOutput output = TransactionOutput.forSending(amount, address);
      String expectedOutputString =
          'e803000000000000160014b247a00acc1cc2c0b4be0d3c38d866f9c08d244a';
      //print(output.amount);
      //print(output.serialize());
      expect(output.serialize(), expectedOutputString);
    });

    test('Ouput for sending(p2pkh)', () {
      String address = '1JieyK6YYufbwwcMMm7rB31QJcLQEphpTA';
      int amount = 724300;
      TransactionOutput output = TransactionOutput.forSending(amount, address);
      String expectedOutputString =
          '4c0d0b00000000001976a914c25ae3a6ea9d9d639f1e7c78edeb522629e51dfa88ac';
      expect(output.serialize(), expectedOutputString);
    });

    test('input parsing and serializing (P2PKH)', () {
      String inputString =
          'd06050454abde3bdd947312b9f54439acb097608a47b0b36a23d76820a3a4044000000006a4730440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be0012102742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8dfffffffff';
      TransactionInput input = TransactionInput.parse(inputString);
      expect(input.transactionHash,
          '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0');
      expect(input.index, 0);
      //print(input.serialize());
      expect(input.serialize(), inputString);
    });

    test('input parsing and serializing (P2WPKH)', () {
      String inputString =
          'a463a7a78daffa1bdb1248121adb14b94f70a1fabffc81637f4049c3d65cc69f000000000000000080';
      TransactionInput input = TransactionInput.parse(inputString);
      //print(input.scriptSig.serialize());
      expect(input.serialize(), inputString);
    });

    test('input for Sending (P2PKH)', () {
      String inputString =
          'd06050454abde3bdd947312b9f54439acb097608a47b0b36a23d76820a3a4044000000006a4730440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be0012102742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8dfffffffff';
      TransactionInput input = TransactionInput.forSending(
          '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0',
          0);
      input.setSignature(
          AddressType.p2pkh,
          '30440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be001',
          '02742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8df');
      //print(input.serialize());
      expect(input.serialize(), inputString);
    });
    test('input for Sending (P2WPKH)', () {
      //tx : 9fc65cd6c349407f6381fcbffaa1704fb914db1a124812db1bfaaf8da7a763a4
      //Full : 02000000000101
      //in : db01d2e05c8d032d2f3b54b7322e11dc408789e04960e01d4683cd57c7b970a701000000000000008002572a0000000000001600143c5e7ce7108e9c0fd8845cc124ea60d30a635e95b7480600000000001600146094a72c8f17349e6751db7ecc2d17e6f33cd5b90247304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c0920012103c0c4d5bd6ab4ad72bf4b386db12767aa0043ac1652b621afdcf3eeb299fe2fb400000000
      //     db01d2e05c8d032d2f3b54b7322e11dc408789e04960e01d4683cd57c7b970a7010000006a47304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c0920012103c0c4d5bd6ab4ad72bf4b386db12767aa0043ac1652b621afdcf3eeb299fe2fb400000080
      String inputString =
          'db01d2e05c8d032d2f3b54b7322e11dc408789e04960e01d4683cd57c7b970a7010000000000000080';

      TransactionInput input = TransactionInput.forSending(
          'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db', 1,
          sequence: 2147483648);
      input.setSignature(
          AddressType.p2wpkh,
          '304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c092001',
          '03c0c4d5bd6ab4ad72bf4b386db12767aa0043ac1652b621afdcf3eeb299fe2fb4');
      // print(input.serialize());
      expect(input.serialize(), inputString);
    });

    test('transaction parse and serialize(segwit)', () {
      String segwitTx =
          '02000000000101a463a7a78daffa1bdb1248121adb14b94f70a1fabffc81637f4049c3d65cc69f00000000000000008002e803000000000000160014b247a00acc1cc2c0b4be0d3c38d866f9c08d244a051f000000000000160014d32c7c4dbb9457cff124c786bac87a9a706c5b3a02483045022100c2ce833d29b2bc4048e54fb5a9cb5131f31fe1254d4510339f3bfa2b6c3fe8120220576e45c680b2ab2fa184cf2b6caf7a165b1d5fc61cc165073017104011bfdc42012103324172078ccc5a19cf6db18b0c4bbd135b9d86131d6666bbd494c9474b3eb52600000000';
      Transaction tx = Transaction.parse(segwitTx);
      expect(tx.serialize(), segwitTx);
    });
    test('transaction parse and serialize(legacy)', () {
      String txString =
          '0100000001d06050454abde3bdd947312b9f54439acb097608a47b0b36a23d76820a3a4044000000006a4730440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be0012102742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8dfffffffff01277c5d000000000016001424b3e9491f3eadd9862389d98480acf89bdab07800000000';
      Transaction tx = Transaction.parse(txString);
      expect(tx.version, '01000000');
      expect(tx.outputs[0].amount, 6126631);
      expect(tx.serialize(), txString);
    });

    test('transaction for sending (legacy)', () {
      List<TransactionInput> inputs = [
        TransactionInput.forSending(
            '44403a0a82763da2360b7ba4087609cb9a43549f2b3147d9bde3bd4a455060d0',
            0)
      ];
      inputs[0].setSignature(
          AddressType.p2pkh,
          '30440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be001',
          '02742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8df');
      List<TransactionOutput> outputs = [
        TransactionOutput.forSending(
            6126631, 'bc1qyje7jjgl86kanp3r38vcfq9vlzda4vrccprts0')
      ];
      Transaction tx =
          Transaction.forSending(inputs, outputs, false, version: 1);
      String expectedTxString =
          '0100000001d06050454abde3bdd947312b9f54439acb097608a47b0b36a23d76820a3a4044000000006a4730440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be0012102742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8dfffffffff01277c5d000000000016001424b3e9491f3eadd9862389d98480acf89bdab07800000000';
      expect(tx.serialize(), expectedTxString);
    });
    test('transaction for sending (segwit)', () {
      List<TransactionInput> inputs = [
        TransactionInput.forSending(
            'a770b9c757cd83461de06049e0898740dc112e32b7543b2f2d038d5ce0d201db',
            1,
            sequence: 2147483648)
      ];
      inputs[0].setSignature(
          AddressType.p2wpkh,
          '304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c092001',
          '03c0c4d5bd6ab4ad72bf4b386db12767aa0043ac1652b621afdcf3eeb299fe2fb4');
      List<TransactionOutput> outputs = [
        TransactionOutput.forSending(
            10839, 'bc1q8308eecs36wqlkyytnqjf6nq6v9xxh54wt3fj8'),
        TransactionOutput.forSending(
            411831, 'bc1qvz22wty0zu6fue63mdlvctghumene4de02slve')
      ];
      Transaction tx =
          Transaction.forSending(inputs, outputs, true, version: 2);
      String expectedTxString =
          '02000000000101db01d2e05c8d032d2f3b54b7322e11dc408789e04960e01d4683cd57c7b970a701000000000000008002572a0000000000001600143c5e7ce7108e9c0fd8845cc124ea60d30a635e95b7480600000000001600146094a72c8f17349e6751db7ecc2d17e6f33cd5b90247304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c0920012103c0c4d5bd6ab4ad72bf4b386db12767aa0043ac1652b621afdcf3eeb299fe2fb400000000';
      //   02000000000101db01d2e05c8d032d2f3b54b7322e11dc408789e04960e01d4683cd57c7b970a701000000000000008002572a0000000000001600143c5e7ce7108e9c0fd8845cc124ea60d30a635e95372e0000000000001600146094a72c8f17349e6751db7ecc2d17e6f33cd5b90247304402201627e63472fc39db307a5db0e0450748fc6ea876c6376da7b1885a7464f2441302206ea2e3257755efa6552d4cb2082a6a4595fdff512411f51785ab7453ad3c0920012103c0c4d5bd6ab4ad72bf4b386db12767aa0043ac1652b621afdcf3eeb299fe2fb400000000

      //Transaction parsedTx = Transaction.parse(expectedTxString);

      //expect(tx.outputs[1].serialize(), parsedTx.outputs[1].serialize());
      expect(tx.serialize(), expectedTxString);
    });
    test('transaction hash test', () {
      String expected =
          '739cb2318c3fa62fa4ba7871d1d6e635a48946ed44fe003707ffa46abf23b886';
      String txString =
          '010000000001018936b7c6840b2be2af7967657e2a3e474438f04cdc42f405094e7fe6a91865510300000000ffffffff01d47a010000000000160014963a615f258bddc9b7cbf941c0ff2b81644dcb8902483045022100e997cf4fd392f3b0355ce123091a063b22f405c9fae2000d01bd9fa50445883b02200668d076901356496274073623316e1d7ff98f4d78bb4245c1f12c3c0020e756012103b05b5d2e09d5eeaeb68205f3ba45763290deebc19fd950eab7c927d9aad7a81700000000';
      Transaction tx = Transaction.parse(txString);
      expect(tx.transactionHash, expected);
    });

    test('fee vByte estimation test (segwit)', () {
      //tx hash : b90142f046531e43c69a09b3142bc5b15ffa888335bb9e1b4e0a483cfff027ba
      String tx =
          '01000000000109a7dacf9d91d9f78ec37271cfe24f519b04085a1a61e7e4457a85ec40918fb7ae0000000000ffffffff24b2f565f271ec7219025b937fa49a6fa8d9a86a9602501ca8f9ea211b6909f70400000000ffffffff50db665b212d8e0be5f6a9f617f620e4971db8bd7f75e24ba2ed607de702eb770000000000ffffffffedb09c9fd86daaff36a999ec6cdc1fed186c652a2a91820e1c8d97f374117fa00100000000ffffffff79ba5ebd18d995f3134e6a9880e2b69347ba0813c1cdf3827a2340675bf2027f3300000000ffffffffc6b42643c67370800d9f5ada176467a547f2e8bfd8bce369eac29a3307d6f3e90000000000ffffffff96fe3565228e5f2dba452fec065ae039c571e038990d8c44ea046bf6168ba1df0500000000ffffffff419bbb8ec34b94e6d65fb61d0bdf147e6ec500d89761a9f5a2e211489e6a29470200000000ffffffffdd1e03d9618f8b8d95924397965695ce0f1f99b83d69ecd8bbc4923e20df78430100000000ffffffff014b5c18090000000016001439440eae862e099f315c7726a6c3c53bc2aa4dea0247304402207183b2826ad09a2adeefbf912ef115df2bf4318c51c36782e4abfde11a7a5aca02206cb6be32a14a1b4bc90292692203c0074d5ba24bb73ceb6a31720c54c8dcad55012102a8e2a56e175b061342b18e643da1b3f4808961cf0470916101f6496bfe85c43b024830450221008f68317f43ffd80287c5e2e7503dc685a08a0594b6edaed49073be306450ee5902205c1bf0fb413b871105e3e61996b9e3bcbc68b8dcfc17a2afc0aa8adc05a29d520121029713b2191907cda9a18fef2e430643274e9e4d2908356a0e70a089f7e361f43d024730440220497e8508bcf4296b96bcc4bf0ab05d25b5cd285dec1810e9d306b4756d70f82b0220417e6c156add566648c737f421911314047d002cfbfececca3b6eff790e5f61e0121038b05e03867b7c85337ee43d8da89ee45b22578b7ee85c05d094058e8c8dcc9d602483045022100dd455f341578def7d932a6bfca5052bd0325bf19ab47c027685f492de175470f022079c6f3bf71c58ecf1fd891be0a000e74edd0c62d602469efa96c23b2e71c49860121020c242b1417dfd734187edd811f0fd0a85312656703d9c98c8d825d247c8766810247304402202b8c4a38a834be1e6fe4a8752101d8a355bb50434c3dc62e99ba3461a984df5d0220064ccc4c13a37c45ca4a1d991edbd7dce453226224efcea75bce973a22c0bcfa0121034cd7d61a7d30b514c18ae8d996ed1c9769e2b9ae5e4482ed781852de35ec1bcc02473044022040d998ded722e73f0971e612dc2baf86226352a44c32ebc73586ffca6ce48ae5022024892b15cf4b1b3e38bc11fa84c00ccfde1707cf745819836e18fdf9dc873770012103d7e0d06a41bec4e48a7297c49934a52ab03ed3e8e51c45fb38c3e7e7cfb047cb024730440220711a538e313a585be3c7c74908d9641119cdb5ea45b72c005d94f8140d1a2ca602202a8ad0e475415bddb74dff533e576d955e2ebd8e03e3bbd815b00a74f56f4c4901210360a5f7a62d1a98e67d5e7f14d9460760a4da897a95a8b3bd1287aa48cecc8ca202483045022100ac854da2b8d1b04100460d6a4d1749e23bddda0121e5ec7adef8a99ab2fa315302203cb41c84bc445ad7b3089d781e0a8500e43e9d48ef8d1f29572dbf99914f849c012102ecb1013548cbe6f38fbce5335346f178ed86d7c32402ff2e1ad58a685f90211d02483045022100863150c20c3a0b9e0978f6dd99e0692a22f3cc25a83e7b7110bb0c7a5287ebf902203d48b37068fa48e8026fb14e69311a6792baa447eeed1e11cf5201be6b9fdd80012102d04377858c7b83e523e34401ab2b6fc434da2555fb6d44e8e321ec5dc028361400000000';

      Transaction transaction = Transaction.parse(tx);
      double vByte = transaction.getVirtualByte(); //652.25
      expect(vByte, 652.25);
      int calculatedFee = transaction.calculateFee(1); //100000
      for (int i = 0; i < transaction.inputs.length; i++) {
        TransactionInput input = transaction.inputs[i];
        // print(input.witness[0].length);
        // print(input.witness[1].length);

        if (i % 2 == 0) continue;
        input.witness = [];
      }
      int estimateFee = transaction.estimateFee(1);
      expect(calculatedFee, estimateFee);
    });

    test('fee calculation test (legacy)', () {
      //tx hash : b90142f046531e43c69a09b3142bc5b15ffa888335bb9e1b4e0a483cfff027ba
      String tx =
          '0100000003efdad76b8da190878c1de4c92fd4aaa0a287984171a4398c1140df11663cb84c010000006b483045022065db71606b84edc291eb2ec55e49ee2fd44afef8b20b4ef88fc2a01c2ba6e963022100dfb24228f2f80574d64a3a2964c5b3d054c14f0bf18c409f72345331271b5020012102a1e806a0c19aaf32363eb19e91a901eafdfc513d13f632f4e2a39f3cb894ad27ffffffff670fa789f11df8b202f380ebc6b4f76fa312f6bfb11494811f00411d7bbb0ae0010000006b4830450221009b5fe2b2bff2a9801725351ae2a8eb410b10b6fecb44edb442ee750e6825f1a4022038e19b3b0e3a95b4a3952dde87efc049d4a72a4424872ab768f7fb3220be4c1e0121032256cb5a8e6d3c9354da72369b939a35febb80d35e6afb50e6f348c20c6c6c05ffffffff52dd5a0965f2d36850f3d2ddeb1457cd72e1cd5a325656af44a3c6ba9f2d42fa010000006c4930460221008a9bf9a1ba9b4125ac9b8cf10423447ad8c7ede3414028237c4c0e0b3b3dc4fd0221009f94721c04b7d4eb33bb1aad61daf98b6ed05dfbf5e3225ae9b3afe24b8924d50121028b04194cb938044761bb93d3917abcce13f910a0500c08e61bdaaf5ea29b5ca0ffffffff02b0c39203000000001976a9148a81571528050b80099821ed0bc4e48ed33e5e4d88ac1f6db80a010000001976a914963f47c50eaafd07c8b0a8a505c825216a4fee6d88ac00000000';

      Transaction transaction = Transaction.parse(tx);
      double vByte = transaction.getVirtualByte(); //523
      expect(vByte, 523);
    });

    test('fee estimation test 1', () {
      //tx hash : a4e280d47a4afadee6f13e7cdf1d18e49e1c027a8e01924ec8799bdacfb6acd5
      String tx =
          '010000000001019df3834eb1d892b9db3c92653f6c1208bda8dc7661a6ea532246dba86551c5bb000000000083e3ffff029c64040000000000160014825f31d0f7cf9912fbb64e81f4662caf6adbf9b804030100000000001600145cd12eff2417fc0121888480cf7db19a5e55d0710248304502210089500e89119ad29e3f2ca5e8b104bd0d6a05687b09066a5077ba159c5acfa75602204f5d6f521a5303025f3477a752c692b74c10de107bf3c9dd96806f311eacb3db012102b20826da311c3f06855c8e6add1c51438d81a6d3ea768aee19060e5027fc6d6000000000';

      Transaction transaction = Transaction.parse(tx);
      for (TransactionInput input in transaction.inputs) {
        input.witness = [];
      }
      int expectedFee = transaction.estimateFee(1);
      // print(expectedFee);
      expect(expectedFee - 140, lessThan(3));
    });

    test('fee estimation test 2', () {
      //tx hash : a1aedb6973783e45defddecd50043f7f0fcbbc755d46e2cec393ad4b33deff53
      String tx =
          '010000000001015f951a9337793e6bb8c6c41c9d85a34fbf156b6495de67fee97b4a7ef92d9b4f1400000000ffffffff15cba5130000000000160014f40d7acb82233d06b219bc0f89a94860787cfbe86d5f000000000000160014c9c279f8143ff32c745920fb2ce120a9f286aaf1c0ab00000000000016001448f4dce0393cabe8af330474542c773f9eb91645d57705000000000016001439880614d8771a795c6fe9507ce920dab32e752267900600000000001600141b3eb97ed29d5d31badef77847e99a9e4c466a5f06be0600000000001600146abee8747cdd6dda28a59f7f148dc7a31ba690024ba9000000000000160014f7539d8d9e0da8a7380a1403503132d502ba3d251a890000000000001976a9145a401e541e45df31d0024eb5e59688c9ebfa836488acc5ca0500000000001600147b92c2159d50a69cc6584ab22fbd7d0094ea1af0769d0100000000001600143b921f7bd30cf71cc01aa4670bc2ce74a8ccb5cafb610200000000001600146b4c248ce7e186de5eb093d0c403f93a4142bba1755e16000000000016001418e5a05c4bbd977bf4f30304259bece4a2cd2bcc933b1600000000001976a914997dd380d7be2848cfe69fcdf20342399dc9bde288acf3f40a0000000000160014ce6d8f72897712be7f43cf8b8e9c3d340b9ca1d8f62c0200000000001600147b64e1ed851032156e3d8a82f78d0e82370ef5cba365010000000000160014cca5b0660e02770a5e2682a7eaa31846740c6cf5768b00000000000017a914b09182b4f234d1ac50b4734124efc1f777b3308f87bd4d1f00000000001600143a062ea9f514a8a0001fac1de7a3d80bea3ab6375b3a0000000000001976a914d402b90e5ee5689fe2330b5b94c15a163f1b80de88ac0d0d0100000000001600140d1c9bf9043a39f6077a68d977bef862605763fe34cf93e10100000016001408da93bfad48bddcdaf49e65248c3195a1838caa0247304402203b92afe5289a1d0a158feaf1239921246c63f7f5d95aba9d6994e469a458b7d1022066915f004ed1bc0f1cbdc4209d23a321151e7a85da7e5d61a44c90edb27cfcce0121022a51bd8200f44d72e94fa623ad6f79efb10fa6a873b5a8cf1c63b47f6301729b00000000';
      Transaction transaction = Transaction.parse(tx);
      for (TransactionInput input in transaction.inputs) {
        input.witness = [];
      }
      int expectedFee = transaction.estimateFee(1);
      // print(expectedFee);
      expect(739 <= expectedFee && expectedFee <= 741, true);
    });

    test('length test', () {
      String tx =
          '010000000001019df3834eb1d892b9db3c92653f6c1208bda8dc7661a6ea532246dba86551c5bb000000000083e3ffff029c64040000000000160014825f31d0f7cf9912fbb64e81f4662caf6adbf9b804030100000000001600145cd12eff2417fc0121888480cf7db19a5e55d0710248304502210089500e89119ad29e3f2ca5e8b104bd0d6a05687b09066a5077ba159c5acfa75602204f5d6f521a5303025f3477a752c692b74c10de107bf3c9dd96806f311eacb3db012102b20826da311c3f06855c8e6add1c51438d81a6d3ea768aee19060e5027fc6d6000000000';
      Transaction transaction = Transaction.parse(tx);
      expect(transaction.length + transaction.witnessLength,
          transaction.serialize().length ~/ 2);
    });

    test('maximum sending', () {
      // test hash : 436409086b0934e78c12213beac100164d51ac50299d6223a46a806b67a68d4b
      int feeRate = 101;
      TransactionInput input = TransactionInput.forSending(
          '85629775dd57cb5331c48e8d0202c9c76461efe9a3d27c025e42aa293360e2e8', 0,
          sequence: 4294967295); //amount : 152599200
      Transaction tx = Transaction.forMaximumSending(
          [input],
          'bc1qh8j8a69gs896qczykgfdxh6r9277dhkyjh7frz',
          152599200,
          true,
          feeRate);
      tx.inputs[0].setSignature(
          AddressType.p2wpkh,
          '304402207bc1288a3efb98b2dd99001ece3b21c25d92a613b74298cb42724f79abfecff8022046ae1fc05f24d6fe2bf181c278a885e8b1a733538270795ece5fd145b5ca17b401',
          '037f96ecf60295840ee32dd0d7e8d914bfce21932b4dd1e5acc027cd2a77e42cc7');

      // print(tx.outputs[0].amount);
      int fee = tx.calculateFee(feeRate);
      // print(fee);
      expect(fee, inInclusiveRange(11000 - 50, 11000 + 50));
    });

    test('has signature', () {
      String unsignedTx =
          '020000000001016520eede29c5e034036a461980149268e263fed8a5b8e527ead8862123e3906b01000000000100000001f82a00000000000016001473f7aa4db6847eab27c59214f6ed7254627e7de00000000000';
      String signedTx =
          '020000000001016520eede29c5e034036a461980149268e263fed8a5b8e527ead8862123e3906b01000000000100000001f82a00000000000016001473f7aa4db6847eab27c59214f6ed7254627e7de002483045022100f369a3e1bdfb62a3ff875fa60bc9834326dead789a24ffcb2faf5f48628240e8022014cc216309a8ded296597cfd2680528729c0a55e43826d8af7d160d45be3df860121033b0492bf5c0a0222a55cdea04cdc022b1751112381ae6e9970319b3d6b161db900000000';
      expect(Transaction.parse(unsignedTx).hasAllSignature(), false);
      expect(Transaction.parse(signedTx).hasAllSignature(), true);
    });

    test('validate signature', () {
      String txString =
          '020000000001016520eede29c5e034036a461980149268e263fed8a5b8e527ead8862123e3906b01000000000100000001f82a00000000000016001473f7aa4db6847eab27c59214f6ed7254627e7de002483045022100f369a3e1bdfb62a3ff875fa60bc9834326dead789a24ffcb2faf5f48628240e8022014cc216309a8ded296597cfd2680528729c0a55e43826d8af7d160d45be3df860121033b0492bf5c0a0222a55cdea04cdc022b1751112381ae6e9970319b3d6b161db900000000';
      Transaction tx = Transaction.parse(txString);
      String prevTxString =
          '02000000000101b388ce3d349385311d8c6e90217e206a66d30acb191369145779c2700a4a3d850000000000fdffffff0223e7141200000000160014c9d118b800a191f330e805dde37906bd8f703a8f042d000000000000160014cb325c29ac1d9f9c56ab77c7f659f6a304a7bd020247304402206c32ce7dce76088fdb81c36bba110ae4add38ecebff7ae03c36308293a0df97902203f78de99e909195bf0a8149650aed533ebab61c98be4d6adb886463dd550e3ff012102c78711069178ff17d77be53a7acedbbacac4daca293e42c61f7303362108fd2265052b00';
      Transaction prevTx = Transaction.parse(prevTxString);
      String utxo = prevTx.outputs[1].serialize();
      expect(tx.validateSignature(0, utxo, AddressType.p2wpkh), true);
    });

    test('validate signature (exception)', () {
      String txString =
          '020000000001016520eede29c5e034036a461980149268e263fed8a5b8e527ead8862123e3906b01000000000100000001f82a00000000000016001473f7aa4db6847eab27c59214f6ed7254627e7de002483045022100f369a3e1bdfb62a3ff875fa60bc9834326dead789a24ffcb2faf5f48628240e8022014cc216309a8ded296597cfd2680528729c0a55e43826d8af7d160d45be3df860121033b0492bf5c0a0222a55cdea04cdc022b1751112381ae6e9970319b3d6b161db900000000';
      Transaction tx = Transaction.parse(txString);
      String prevTxString =
          '02000000000101670c2a20b939d70170af0fc3be6e4baecf9a003df9b25ac64d3b0d18b43dc12b0200000000fdffffff033f3fc0380000000022512051db6dd7e0ceb9a4b189078555bffbeebd589d6237813b9c74bc457997c21d60e803000000000000160014cb325c29ac1d9f9c56ab77c7f659f6a304a7bd02960f000000000000225120eabe98a28e805ba56a0bce762af410f3998ee10e4c919d964dc91cf096f5a9cf0140875bc3d6e6f00d6020c095f5cc20744a1bf6ebb7bd2dbee415b8346024c6db13b1389809468d2deb6ce221c27b5bdc58a38a4a91909b5f6ac3fea26abe184347570b2b00';
      Transaction prevTx = Transaction.parse(prevTxString);
      String utxo = prevTx.outputs[1].serialize();
      expect(tx.validateSignature(0, utxo, AddressType.p2wpkh), false);
    });
  });

  group('Signature test', () {
    SingleSignatureVault vault = SingleSignatureVault.fromSeed(
        Seed.fromMnemonic(
            'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
        AddressType.p2wpkh);

    SingleSignatureWallet wallet =
        SingleSignatureWallet.fromDescriptor(vault.descriptor);
    test('Simple signature test', () {
      String message = Hash.sha256fromHex("1234567890ABC");
      int index = 0;
      String signature = vault.keyStore.sign(message, index, isDer: false);
      expect(
          true,
          wallet.keyStore
              .validateSignature(signature, message, index, isDer: false));
    });

    test('Simple signature test (DER)', () {
      String message = Hash.sha256fromHex("1234567890ABC");
      int index = 0;
      String signature = vault.keyStore.sign(message, index);
      expect(
          true, wallet.keyStore.validateSignature(signature, message, index));
    });
    test('Segwit sign test', () {
      String target =
          'c37af31116d1b27caf68aae9e3ac82f1477929014d5b917657d0eb49478cb670';
      Transaction tx = Transaction.parse(
          '0100000002fff7f7881a8099afa6940d42d1e7f6362bec38171ea3edf433541db4e4ad969f0000000000eeffffffef51e1b804cc89d182d279655c3aa89e815b1b309fe287d9b2b55d57b90ec68a0100000000ffffffff02202cb206000000001976a9148280b37df378db99f66f85c95a783a76ac7a6d5988ac9093510d000000001976a9143bde42dbee7e4dbe6a21b2d50ce2f0167faa815988ac11000000',
          isEmptySignature: true);
      // TransactionOutput utxo1 = TransactionOutput.fromScript(
      //     620000000,
      //     ScriptPublicKey.parse(
      //         '232103c9f4836b9a4f77fc0d81f7bcb01b7f1b35916864b9476c241ce9fc198bd25432ac'));
      TransactionOutput utxo2 = TransactionOutput(
          Converter.intToLittleEndianBytes(600000000, 8),
          ScriptPublicKey.parse(
              '1600141d0f172a0ecb48aee1be1f2687d2963ae33f71a1'));
      //String sigHash1 = tx.getSigHash(0, utxo1.serialize(), AddressType.p2wpkh);

      String sigHash2 =
          tx.getSigHash(1, utxo2.serialize(), AddressType.p2wpkh.isSegwit);

      expect(sigHash2, target);

      String privateKey =
          '619c335025c7f4012e556c2a58b2506e30b8511b53ade95ea316fd8c3286feb9';

      HDWallet hdWallet = HDWallet.fromPrivateKey(
          Converter.hexToBytes(privateKey), Uint8List.fromList([0, 0, 0, 0]));
      //print(Converter.bytesToHex(hdWallet.publicKey));

      Uint8List signature = hdWallet.sign(Converter.hexToBytes(sigHash2));

      String r = Converter.bytesToHex(signature.sublist(0, 32));
      String rLength = Converter.decToHex(r.length ~/ 2);
      String s = Converter.bytesToHex(signature.sublist(32, 64));
      String sLength = Converter.decToHex(s.length ~/ 2);
      String rs = '02$rLength${r}02$sLength$s';
      String derString = '30${Converter.decToHex(rs.length ~/ 2)}${rs}01';

      String targetSignature =
          '304402203609e17b84f6a7d30c80bfa610b5b4542f32a8a0d5447a12fb1366d7f01cc44a0220573a954c4518331561406f90300e8f3358f51928d43c212a8caed02de67eebee01';
      expect(derString, targetSignature);
      //print(derString);
    });

    test(
        'Testnet recall Tx : 90af61b59a23f51e6308f3c69c59df5c3f2dc0b71931321324b9591f36b28fa2',
        () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.testnet);
      SingleSignatureVault vault = SingleSignatureVault.fromSeed(
          Seed.fromMnemonic(
              'walk nose vibrant ankle advance frame violin apart summer depart volume squeeze decide visit manage tomorrow demand office minimum method manage arm dwarf cement',
              passphrase: 'ABC'),
          AddressType.p2wpkh);

      // vault.addressBook.map.forEach((key, value) {
      //   print('$key : $value');
      // });

      TransactionInput input1 = TransactionInput.forSending(
          "6b90e3232186d8ea27e5b8a5d8fe63e26892148019466a0334e0c529deee2065", 1,
          sequence: 1);

      TransactionOutput output =
          TransactionOutput.forSending(11000, vault.getAddress(1));
      Transaction tx = Transaction.forSending([input1], [output], true);
      // print("tx : ${tx.serialize()}");

      TransactionOutput utxo1 = TransactionOutput.forSending(
          11524, 'tb1qeve9c2dvrk0ec44twlrlvk0k5vz200gz8pu2wn');

      String sigHash =
          tx.getSigHash(0, utxo1.serialize(), AddressType.p2wpkh.isSegwit);
      // print("sigHash : $sigHash");
      // print("utxo1 : ${utxo1.serialize()}");
      String sign = vault.keyStore.sign(sigHash, 0);
      tx.inputs[0].setSignature(
          vault.addressType, sign, vault.keyStore.getPublicKey(0));
      // print(tx.serialize());
      expect(tx.serialize(),
          '020000000001016520eede29c5e034036a461980149268e263fed8a5b8e527ead8862123e3906b01000000000100000001f82a00000000000016001473f7aa4db6847eab27c59214f6ed7254627e7de002483045022100f369a3e1bdfb62a3ff875fa60bc9834326dead789a24ffcb2faf5f48628240e8022014cc216309a8ded296597cfd2680528729c0a55e43826d8af7d160d45be3df860121033b0492bf5c0a0222a55cdea04cdc022b1751112381ae6e9970319b3d6b161db900000000');
    });
  });

  group('PSBT test', () {
    test('psbt instance test 1', () {
      String genPsbt =
          'cHNidP8BAHECAAAAAWUg7t4pxeA0A2pGGYAUkmjiY/7YpbjlJ+rYhiEj45BrAQAAAAD+////Ak4EAAAAAAAAFgAUc/eqTbaEfqsnxZIU9u1yVGJ+feDBJgAAAAAAABYAFI/e1ckmFCiom0RpZFOnYL+LGj00AAAAACIBAoVTlNWX9SGtm5cFiwwI8Wa3/ghN1Rcn5sFq/HiYIljOEHdHvlRUAACAAQAAgAAAAIAAAQDeAgAAAAABAbOIzj00k4UxHYxukCF+IGpm0wrLGRNpFFd5wnAKSj2FAAAAAAD9////AiPnFBIAAAAAFgAUydEYuAChkfMw6AXd43kGvY9wOo8ELQAAAAAAABYAFMsyXCmsHZ+cVqt3x/ZZ9qMEp70CAkcwRAIgbDLOfc52CI/bgcNruhEK5K3Tjs6/964Dw2MIKToN+XkCID943pnpCRlb8KgUllCu1TPrq2HJi+TWrbiGRj3VUOP/ASECx4cRBpF4/xfXe+U6es7busrE2sopPkLGH3MDNiEI/SJlBSsAAQEfBC0AAAAAAAAWABTLMlwprB2fnFard8f2WfajBKe9AiIGAzsEkr9cCgIipVzeoEzcAisXUREjga5umXAxmz1rFh25GMzw5sZUAACAAQAAgAAAAIAAAAAAAAAAAAAAAA==';
      PSBT psbt = PSBT.parse(genPsbt);
      expect(psbt.derivationPath?.path, "m/84'/1'/0'");
      expect(psbt.unsignedTransaction!.transactionHash,
          'b968c83476792ac3ead52749f61957ce926dca5d9749fa6eed5440ebe3e44290');
      expect(psbt.inputs[0].witnessUtxo?.amount.toString(), '11524');
    });

    test('psbt parse test 1', () {
      String psbtString =
          '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';
      PSBT psbt = PSBT.parse(psbtString);
      expect(psbt.serialize().replaceAll("AA==", ""), psbtString);
    });

    test('psbt parse test 2', () {
      String psbtString =
          'cHNidP8BAKACAAAAAqsJSaCMWvfEm4IS9Bfi8Vqz9cM9zxU4IagTn4d6W3vkAAAAAAD+////qwlJoIxa98SbghL0F+LxWrP1wz3PFTghqBOfh3pbe+QBAAAAAP7///8CYDvqCwAAAAAZdqkUdopAu9dAy+gdmI5x3ipNXHE5ax2IrI4kAAAAAAAAGXapFG9GILVT+glechue4O/p+gOcykWXiKwAAAAAAAEHakcwRAIgR1lmF5fAGwNrJZKJSGhiGDR9iYZLcZ4ff89X0eURZYcCIFMJ6r9Wqk2Ikf/REf3xM286KdqGbX+EhtdVRs7tr5MZASEDXNxh/HupccC1AaZGoqg7ECy0OIEhfKaC3Ibi1z+ogpIAAQEgAOH1BQAAAAAXqRQ1RebjO4MsRwUPJNPuuTycA5SLx4cBBBYAFIXRNTfy4mVAWjTbr6nj3aAfuCMIAAAA';
      PSBT psbt = PSBT.parse(psbtString);
      expect(psbt.serialize().replaceAll("AA==", ""), psbtString);
    });

    test('psbt instance test 2', () {
      String psbtString =
          'cHNidP8BANgBAAAAAiA1xcd/piDGOrEAk0EkJ1R+w+u3t6kUa1I0Gt3cB94UDAAAAAD9////+uZSyCfH79Q3JxE8H0ISJfFzHw7Lg/hdJeJqKOS514QAAAAAAP3///8ETAQAAAAAAAAWABS1RUJBOFW8oIlOhVt4WM0HvKh7gBQFAAAAAAAAFgAU8UwR/kro9gqHyc7Ff4JC+m6UksmwBAAAAAAAABYAFMSNq3RDJdWnCCNQdacqD0+mxRZvsNsAAAAAAAAWABTxTBH+Suj2CofJzsV/gkL6bpSSybVxJwAAAQD9PQgCAAAAAAEBl1faOpIUOOE39O7nc7wFaoI4EDvr6YWEZrSjR3nk0kYBAAAAAP3///870AcAAAAAAAAiUSB41ZeH6VY4dmYbYjG7WKOXClvXIovKRehsufx5fZB3Gk4bAAAAAAAAFgAUmuFp100YfbVWMgPYWUymepQJaQhOGwAAAAAAABYAFNTc2WOcwZEos3+jLD6dqXRnTK2dThsAAAAAAAAWABQsv3IFyzgo+UZzfU37WXRY7uf1d7gLAAAAAAAAFgAUp0xNEcGFE6y1shIJGPRq7BxIyIy4CwAAAAAAABYAFC8DGsxscZQ/pzBxEkbwNFeTtFM8irMkAAAAAAAiUSD67BwiZWl/Po4xIiGHEhzN1eRIX6wZE9filhqzrrte2E4bAAAAAAAAFgAUHNvVRO9avbmCXJgVVwMV1g0i0xboAwAAAAAAACJRIF43kymSsN0WG7dJPCyj/J64FcxVhS5pL5zrVMXmpS4DuAsAAAAAAAAWABSoSqJYvf0kKvt/FOjIAwH1+zAAU9AHAAAAAAAAIlEgQPULNXNOr097hvuBeDn3Lw6S4eXgilSkyAdnnV8ASznQBwAAAAAAACJRIFDWVp4cSnlRruveiA3kkgEyv9qAc9PQC2RH1eJHS/pK6AMAAAAAAAAWABS1RUJBOFW8oIlOhVt4WM0HvKh7gE4bAAAAAAAAFgAUVx2qRlEpZ596y7+gf0gQl4D7Ux3gLgAAAAAAABYAFOgAaz2XcG/ERcsvrNKfHarIMKyElg8AAAAAAAAWABQscbNNf4epNqAWLcMp9F1yACJ8qaAPAAAAAAAAIlEgBSsAiEmG2fNtu3MkVqiseMjJt5lQs6RCitpTi33vSONOGwAAAAAAABYAFPK6oluBIv4seo/AsvSaJ/oMNDsMcBcAAAAAAAAWABTpSn6EJzKNZc3IoF0Ifw1i/02/jugDAAAAAAAAFgAU8Nu7doN2IMRyFe2oAywt6k3Sejq4CwAAAAAAABYAFPnZdFMnYOhpJ/5nbYPK3dv4ajwIuAsAAAAAAAAWABRjLpAhPq0BYYrJ1vjWP8jfcaj+SrgLAAAAAAAAFgAULKf4gsgPttO80N/dvVDLa9uyc8W4CwAAAAAAABYAFLOawkSKkzmCwOYPxmWZGciBpt0IThsAAAAAAAAWABS9MSBXSC41DwcBB2LWYVJbHdkW+7gLAAAAAAAAFgAUmp4nMiXmaCFTYxDdWLBtERj84ru4CwAAAAAAABYAFJmEuC9aP5AHizXs+ESoWQQ3TD2LuAsAAAAAAAAWABSe1ZRfXz/BpA9pEd8Ig8GWa57LfrgLAAAAAAAAFgAUThXcLKxLByVaJIH+CD6Mtx2EuAO4CwAAAAAAABYAFIphWqa7KNfP9yQFGv5UE/XXFiXbuAsAAAAAAAAWABT4taAOIkhQ/p2x7/c8RB1PBFVJbdAHAAAAAAAAFgAUDNJn8nX2FDN9lRaNNI6eItDf6cXoAwAAAAAAACJRIPxIqkOLqd90nyUZb9gOl9MMRxSQNfS0PHesX5TPfPr3cBcAAAAAAAAiUSAeyArV0BXs9YzrFHUypGQQ85vwhA+ni4+W7y+xtQntDdAHAAAAAAAAIlEgEfM800bsFJzTmZYwpN37cXlw63vmB/s1di9K5AyF3GlwFwAAAAAAABYAFGEtSxhvR3rGOOYnAnYuPeJ6kNEduAsAAAAAAAAWABQY05CynqPwd0xiLEnddHtuOmd2crgLAAAAAAAAFgAUp0Lc/989r5oJuROrAaEXPCerdYO4CwAAAAAAABYAFODWIy/YPzMN/aydkyUoWIW8bbrmThsAAAAAAAAWABTv0S2FWp3/Qyi3txq7jlGLGI7tRbgLAAAAAAAAFgAUagidCO+nR4OkjrsSAxBh4DGFnvy4CwAAAAAAABYAFFK+NdKv5UjVOJAuicj2YPjodw81cBcAAAAAAAAWABQAbyMRF1N7YZ1qLqSvUPq7CxJxUbgLAAAAAAAAFgAUNbDKz2yHOuRPcZ9UF7gIPStbJC3oAwAAAAAAABYAFFYhdmS2wtgLXzqAzt/bFRDS3/OQpjYAAAAAAAAWABQtMGeoWqOpHgQUl5v4u35sXNej5ugDAAAAAAAAFgAUk1vkka8Ch7uxMJIzhCNS4xATFBzQBwAAAAAAABYAFGjGNREV3Ro27dvwhRFTrxYBT082ThsAAAAAAAAWABRKO+3WSpkoNIQJgYt8TLvwleM65U4bAAAAAAAAFgAUqEL8a9E+DN8g2CsNioVQGESDVhi4CwAAAAAAABYAFDwpNbIjOC+LuKVIaU0lKd7PZ7tOuAsAAAAAAAAWABTotF8awwjhYZv6ld/lrePUO/arNLgLAAAAAAAAFgAUIVlbsicjUYc+GK6QIRPkl637e/TQBwAAAAAAACJRIJOlx+r0brWX9LgNPOC3kx03qSXMF5Na3ZFIEm7jrYF8ThsAAAAAAAAWABQJIUoPTt7geI5eIiAHOyJ13SuIyegDAAAAAAAAFgAUobLK/Fpn/TV3zsB5oj7y+FzUZTy4CwAAAAAAABYAFKlPJbTMjemGOn47Ye9xUpNvCIWsuAsAAAAAAAAWABRwNWEOW/9mvhemA6KRb1lUA8o9x7gLAAAAAAAAFgAUynOwBbBmtNLGH1qcp0JpF8XXB9cCRzBEAiB9vbguiayyJ2DMSMMapPV2oezh0L0kQFTCyVvW5+0N1wIgUh515mEWKNpoStth7zoRBqC1LZ+WLQhMBtuKY8nHANgBIQIKrChpW3DO5pwI1bjLVDX1SjSlYmWKx5zXpcdavMBIhdJoJwABAR/oAwAAAAAAABYAFLVFQkE4VbygiU6FW3hYzQe8qHuAIgYCRsGOp8ViS4fl9lpghCyaIrJ65+NjCpWr6zVFUll2GCQYmMfXdFQAAIABAACAAAAAgAAAAAAAAAAAAAEAvwIAAAAAAQFsGVY6XEFc+5KCE4jmpSnc4upA1Y6xDQf7w0qUNTqYdwAAAAAAAQAAAAHn5gAAAAAAABYAFMSNq3RDJdWnCCNQdacqD0+mxRZvAkcwRAIgadmTL9bf5NBYCZeOlQh1ZzCRe7EGs0YxQcxbUaK7cG8CIAycPHoyRY0OowG+Mp3xqd0M9j9yMkc/N/Nv3w7871tZASECRsGOp8ViS4fl9lpghCyaIrJ65+NjCpWr6zVFUll2GCQAAAAAAQEf5+YAAAAAAAAWABTEjat0QyXVpwgjUHWnKg9PpsUWbyIGAreJ4sB7Ik8fypffuBdhxBul3jHqGlUp/EcuZxLh7xVOGJjH13RUAACAAQAAgAAAAIAAAAAAAQAAAAAiAgJGwY6nxWJLh+X2WmCELJoisnrn42MKlavrNUVSWXYYJBiYx9d0VAAAgAEAAIAAAACAAAAAAAAAAAAAIgIC+q8/Jxb2rsWiT7FGlYyPL8OWpjSk718idglFUcSdpUAYmMfXdFQAAIABAACAAAAAgAAAAAACAAAAACICAreJ4sB7Ik8fypffuBdhxBul3jHqGlUp/EcuZxLh7xVOGJjH13RUAACAAQAAgAAAAIAAAAAAAQAAAAAiAgL6rz8nFvauxaJPsUaVjI8vw5amNKTvXyJ2CUVRxJ2lQBiYx9d0VAAAgAEAAIAAAACAAAAAAAIAAAAA';
      PSBT psbt = PSBT.parse(psbtString);
      expect(psbt.unsignedTransaction!.transactionHash,
          "71ae48a404ce3ad731981532b3dbbde539f27ffc042c0f830576b50478cc16ea");
      expect(psbt.inputs[1].previousTransaction!.transactionHash,
          '84d7b9e4286ae2255df883cb0e1f73f12512421f3c112737d4efc727c852e6fa');
      expect(psbt.outputs[0].derivationPath!.publicKey,
          "0246c18ea7c5624b87e5f65a60842c9a22b27ae7e3630a95abeb35455259761824");
    });

    test('psbt instance test 3 (with Signature)', () {
      String psbtString =
          'cHNidP8BAFICAAAAAWUg7t4pxeA0A2pGGYAUkmjiY/7YpbjlJ+rYhiEj45BrAQAAAAABAAAAAfgqAAAAAAAAFgAUc/eqTbaEfqsnxZIU9u1yVGJ+feAAAAAAIgEChVOU1Zf1Ia2blwWLDAjxZrf+CE3VFyfmwWr8eJgiWM4Qd0e+VFQAAIABAACAAAAAgAABAN4CAAAAAAEBs4jOPTSThTEdjG6QIX4gambTCssZE2kUV3nCcApKPYUAAAAAAP3///8CI+cUEgAAAAAWABTJ0Ri4AKGR8zDoBd3jeQa9j3A6jwQtAAAAAAAAFgAUyzJcKawdn5xWq3fH9ln2owSnvQICRzBEAiBsMs59znYIj9uBw2u6EQrkrdOOzr/3rgPDYwgpOg35eQIgP3jemekJGVvwqBSWUK7VM+urYcmL5NatuIZGPdVQ4/8BIQLHhxEGkXj/F9d75Tp6ztu6ysTayik+QsYfcwM2IQj9ImUFKwABAR8ELQAAAAAAABYAFMsyXCmsHZ+cVqt3x/ZZ9qMEp70CIgYDOwSSv1wKAiKlXN6gTNwCKxdRESOBrm6ZcDGbPWsWHbkYzPDmxlQAAIABAACAAAAAgAAAAAAAAAAAIgIDOwSSv1wKAiKlXN6gTNwCKxdRESOBrm6ZcDGbPWsWHblIMEUCIQDzaaPhvftio/+HX6YLyYNDJt6teJok/8svr19IYoJA6AIgFMwhYwmo3tKWWXz9JoBShynApV5Dgm2K99Fg1Fvj34YBAAEDBPgqAAABBBcWABRz96pNtoR+qyfFkhT27XJUYn594CICApaPYnyq0NL/g79f7tMP2059h/m9ZVfoDSuJjgdjz4f6GMzw5sZUAACAAQAAgAAAAIAAAAAAAQAAAAAA';
      PSBT psbt = PSBT.parse(psbtString);
      expect(psbt.inputs[0].partialSigs![0],
          '3045022100f369a3e1bdfb62a3ff875fa60bc9834326dead789a24ffcb2faf5f48628240e8022014cc216309a8ded296597cfd2680528729c0a55e43826d8af7d160d45be3df8601');
      expect(psbt.inputs[0].partialSigs![1],
          '033b0492bf5c0a0222a55cdea04cdc022b1751112381ae6e9970319b3d6b161db9');
    });

    test('add sign and serialization test', () {});

    test('psbt generation test', () async {
      // //Repository repository = Repository();

      // Completer<bool> completer = Completer();

      // Timer(Duration(seconds: 1), () {
      //   if (nodeConnector.connectionStatus ==
      //       SocketConnectionStatus.connected) {
      //     completer.complete(true);
      //   }
      // });

      // await completer.future;

      SingleSignatureVault vault = SingleSignatureVault.fromSeed(
        Seed.fromMnemonic(
            'walk nose vibrant ankle advance frame violin apart summer depart volume squeeze decide visit manage tomorrow demand office minimum method manage arm dwarf cement',
            passphrase: 'ABC'),
        AddressType.p2wpkh,
      );
      SingleSignatureWallet wallet =
          SingleSignatureWallet.fromDescriptor(vault.descriptor);

      var syncResult = await nodeConnector.fetch(wallet);
      if (syncResult.isFailure) {
        throw Exception(" - Sync failed : ${syncResult.error}");
      } else {
        print(' - Transaction Sync Success');
        await Repository().sync(wallet, syncResult.value!);
      }

      TransactionInput input1 = TransactionInput.forSending(
          "90af61b59a23f51e6308f3c69c59df5c3f2dc0b71931321324b9591f36b28fa2", 0,
          sequence: 1); //11000
      TransactionInput input2 = TransactionInput.forSending(
          "78342fcec91b178c13ef8d2ba4fbc354d4b817a55d55edd75cff3aa6bc9bba05", 9,
          sequence: 1); //1000
      TransactionOutput output1 = TransactionOutput.forSending(
          1000, 'tb1q65r879rlsca63c2ju4q4832289d9hte7m7mkgm');
      TransactionOutput output2 = TransactionOutput.forSending(10000,
          'tb1q5e7xwfxvm2wq95kla90femh9nvj6at9qzstvu3'); //change m/84'/1'/0'/1/0

      Transaction tx =
          Transaction.forSending([input2, input1], [output1, output2], true);
      PSBT psbt = PSBT.fromTransaction(tx, wallet);
      //print(psbt.toString());
      //print(psbt.serialize());
      expect(psbt.outputs[1].isChange, true);
      expect(psbt.outputs[0].isChange, false);
    });

    test('fee test (sending)', () async {
      BitcoinNetwork.setNetwork(BitcoinNetwork.testnet);
      Seed seed = Seed.fromMnemonic(
          'walk nose vibrant ankle advance frame violin apart summer depart volume squeeze decide visit manage tomorrow demand office minimum method manage arm dwarf cement',
          passphrase: 'ABC');
      SingleSignatureVault vault =
          SingleSignatureVault.fromSeed(seed, AddressType.p2wpkh);
      SingleSignatureWallet wallet =
          SingleSignatureWallet.fromDescriptor(vault.descriptor);

      NodeConnector nodeConnector = await NodeConnector.connectSync(
          'regtest-electrum.coconut.onl', 60401,
          ssl: true);

      var syncResult = await nodeConnector.fetch(wallet);
      if (syncResult.isFailure) {
        throw Exception(" - Sync failed : ${syncResult.error}");
      } else {
        print(' - Transaction Sync Success');
        await Repository().sync(wallet, syncResult.value!);
      }

      // String receiverAddress = wallet.getReceiveAddress().address;
      // String receiverAddress = 'tb1qvy67actlsslmvwpjzk9hnx6jf04g5y26sz5crx';
      // int sendingAmount = 5000;
      // String psbt =
      //     await wallet.generatePsbt(receiverAddress, sendingAmount, 1);
      // int estimatedFee =
      //     await wallet.estimateFee(receiverAddress, sendingAmount, 1);

      // PSBT psbtObj = PSBT.parse(psbt);
      // int unsignedFee = psbtObj.fee;

      // String signedPsbt = vault.addSignatureToPsbt(psbt);
      // PSBT signedPsbtObj = PSBT.parse(signedPsbt);
      // Transaction compTx =
      //     signedPsbtObj.getSignedTransaction(AddressType.p2wpkh);

      // int realFee = compTx.calculateFee(1);

      // print("vByte : ${compTx.getVirtualByte()}");
      // print("real fee : $realFee");
      // print("estimated fee : $estimatedFee");
      // print("unsigned fee : $unsignedFee");

      //TODO : reTest
      // expect((realFee - estimatedFee).abs(), lessThan(2));
      // expect((realFee - unsignedFee).abs(), lessThan(2));
    });

    test('fee test (max sending)', () async {
      BitcoinNetwork.setNetwork(BitcoinNetwork.testnet);
      Seed seed = Seed.fromMnemonic(
          'walk nose vibrant ankle advance frame violin apart summer depart volume squeeze decide visit manage tomorrow demand office minimum method manage arm dwarf cement',
          passphrase: 'ABC');
      SingleSignatureVault vault =
          SingleSignatureVault.fromSeed(seed, AddressType.p2wpkh);
      SingleSignatureWallet wallet =
          SingleSignatureWallet.fromDescriptor(vault.descriptor);

      var syncResult = await nodeConnector.fetch(wallet);
      if (syncResult.isFailure) {
        throw Exception(" - Sync failed : ${syncResult.error}");
      } else {
        print(' - Transaction Sync Success');
        await Repository().sync(wallet, syncResult.value!);
      }

      // String nodeURL = 'blockstream.info';
      // NodeConnector nodeConnector =
      //     NodeConnector.connect(nodeURL, 143, ssl: false);
      // Completer<bool> completer = Completer();

      // late Block currentBlock;
      // Timer.periodic(Duration(milliseconds: 100), (timer) {
      //   if (nodeConnector.connectionStatus ==
      //       SocketConnectionStatus.connected) {
      //     currentBlock = nodeConnector.currentBlock;
      //     if (currentBlock.height != 0) {
      //       timer.cancel();
      //       completer.complete(true);
      //     }
      //   }
      // });

      // await completer.future;

      // var syncResult = await nodeConnector.fullSync(wallet);
      // if (syncResult.isFailure) {
      //   throw Exception(" - Sync failed : ${syncResult.error}");
      // }
      // int feeRate = 5;

      // String receiverAddress = wallet.getReceiveAddress().address;
      // // String receiverAddress = 'tb1qvy67actlsslmvwpjzk9hnx6jf04g5y26sz5crx';
      // String psbt = await wallet.generatePsbtWithMaximum(receiverAddress, 1);
      // int estimatedFee =
      //     await wallet.estimateFeeWithMaximum(receiverAddress, 1);

      // PSBT psbtObj = PSBT.parse(psbt);
      // int unsignedFee = psbtObj.fee;

      // String signedPsbt = vault.addSignatureToPsbt(psbt);
      // // print("signedPsbt : " + signedPsbt);
      // PSBT signedPsbtObj = PSBT.parse(signedPsbt);
      // Transaction compTx =
      //     signedPsbtObj.getSignedTransaction(AddressType.p2wpkh);
      // print(compTx.serialize());

      // int realFee = compTx.calculateFee(feeRate);
      // print("real vByte : ${compTx.getVirtualByte()}");
      // print("real fee : $realFee");
      // print("estimated fee : $estimatedFee");
      // print("unsigned fee : $unsignedFee");
      // print(realFee - estimatedFee);
      // print(realFee - unsignedFee);
      //TODO : reTest
      // expect((realFee - estimatedFee).abs(), lessThan(10));
      // expect((realFee - unsignedFee).abs(), lessThan(10));
    });
  });
}
