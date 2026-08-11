@Tags(['unit'])

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../mock_factory.dart';

void main() {
  group('Transaction', () {
    late Transaction legacyTransaction;
    late Transaction segwitTransaction;
    setUpAll(() {
      NetworkType.setNetworkType(NetworkType.regtest);
      String segwitTransactionText =
          '02000000000101a463a7a78daffa1bdb1248121adb14b94f70a1fabffc81637f4049c3d65cc69f00000000000000008002e803000000000000160014b247a00acc1cc2c0b4be0d3c38d866f9c08d244a051f000000000000160014d32c7c4dbb9457cff124c786bac87a9a706c5b3a02483045022100c2ce833d29b2bc4048e54fb5a9cb5131f31fe1254d4510339f3bfa2b6c3fe8120220576e45c680b2ab2fa184cf2b6caf7a165b1d5fc61cc165073017104011bfdc42012103324172078ccc5a19cf6db18b0c4bbd135b9d86131d6666bbd494c9474b3eb52600000000';
      String legacyTransactionText =
          '0100000001d06050454abde3bdd947312b9f54439acb097608a47b0b36a23d76820a3a4044000000006a4730440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be0012102742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8dfffffffff01277c5d000000000016001424b3e9491f3eadd9862389d98480acf89bdab07800000000';

      legacyTransaction = Transaction.parse(legacyTransactionText);
      segwitTransaction = Transaction.parse(segwitTransactionText);
    });
    group('version', () {
      test('Get version of transaction', () {
        expect(legacyTransaction.version, '01000000');
        expect(segwitTransaction.version, '02000000');
      });
    });
    group('inputs', () {
      test('Get transaction input list', () {
        expect(legacyTransaction.inputs.length, 1);
        expect(segwitTransaction.inputs.length, 1);
      });
    });
    group('outputs', () {
      test('Get transaction output list', () {
        expect(legacyTransaction.outputs.length, 1);
        expect(segwitTransaction.outputs.length, 2);
      });
    });
    group('lockTime', () {
      test('returns the little-endian lock time', () {
        expect(legacyTransaction.lockTime, '00000000');
        expect(segwitTransaction.lockTime, '00000000');
      });
    });
    group('transactionHash', () {
      test('Get transaction hash', () {
        expect(legacyTransaction.transactionHash,
            '5e2a36182c1566495489bb86ce85ef386095a709bc53c7363ec18c99467aa63c');
        expect(segwitTransaction.transactionHash,
            'efb4cadbc8fa6ab7970b461bbc99e506403397bddc3280cbf847c1684b61248b');
      });
    });
    group('length', () {
      test('Get length of transaction', () {
        expect(legacyTransaction.length, 188);
        expect(segwitTransaction.length, 115);
      });
    });
    group('utxoList', () {
      test('Get utxo list if exist', () {
        SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        List<Utxo> utxoList = MockFactory.createUtxoList(count: 2);
        Transaction tx = Transaction.forBatchPayment(
            utxoList,
            {'bcrt1qk4z5ysfc2k72pz2ws4dhskxdq772s7uq6cdqkv': 100000},
            '${vault.derivationPath}/1/0',
            1,
            vault);
        expect(tx.utxoList.length, 2);
      });
    });
    group('totalInputAmount', () {
      test('sums the amounts of transaction UTXOs', () {
        final vault = MockFactory.createP2wpkhVault();
        final utxos = MockFactory.createUtxoList(count: 2);
        final tx =
            Transaction.forSweep(utxos, MockFactory.reveiveAddress, 1, vault);
        expect(tx.totalInputAmount,
            utxos.fold<int>(0, (total, utxo) => total + utxo.amount));
      });
    });

    group('Transaction.withInputsAndOutputs', () {
      test('Generate default transaction', () {
        TransactionInput input = TransactionInput.parse(
            'a463a7a78daffa1bdb1248121adb14b94f70a1fabffc81637f4049c3d65cc69f000000000000000080');
        TransactionOutput output1 = TransactionOutput.parse(
            'e803000000000000160014b247a00acc1cc2c0b4be0d3c38d866f9c08d244a');
        TransactionOutput output2 = TransactionOutput.parse(
            '051f000000000000160014d32c7c4dbb9457cff124c786bac87a9a706c5b3a');
        Transaction tx = Transaction.withInputsAndOutputs(
            [input], [output1, output2], AddressType.p2wpkh);
        expect(tx, isA<Transaction>());
      });
    });
    group('Transaction.forSinglePayment', () {
      List<Utxo> utxos = MockFactory.createUtxoList(count: 5);
      String receiveAddress = 'bcrt1q8e5ghfg8gpe4dlfv7qqck2c2jc47lnllul3puh';
      test('Reject invalid payment amounts and fee rates', () {
        final SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        final String changeAddressPath = '${vault.derivationPath}/1/0';

        expect(
            () => Transaction.forSinglePayment(utxos.sublist(0, 1),
                receiveAddress, changeAddressPath, -1, 1, vault),
            throwsRangeError);
        for (final double feeRate in <double>[
          -1,
          double.nan,
          double.infinity
        ]) {
          expect(
              () => Transaction.forSinglePayment(utxos.sublist(0, 1),
                  receiveAddress, changeAddressPath, 1000, feeRate, vault),
              throwsArgumentError);
        }
      });

      test(
          'Generate transaction from utxo list when change amount is under dust',
          () {
        SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        String changeAddressPath = '${vault.derivationPath}/1/0';

        Transaction tx = Transaction.forSinglePayment(utxos.sublist(0, 1),
            receiveAddress, changeAddressPath, 99800, 1, vault);
        int inputAmount = 0;
        int outputAmount = 0;
        for (Utxo u in tx.utxoList) {
          inputAmount += u.amount;
        }
        for (TransactionOutput output in tx.outputs) {
          outputAmount += output.amount;
        }
        expect(
            inputAmount >= outputAmount + tx.estimateFee(1, vault.addressType),
            true);
        expect(tx.outputs.length, 1);
      });
      test('Generate transactin for single payment (case 1)', () {
        SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        String changeAddressPath = '${vault.derivationPath}/1/0';
        List<Utxo> utxos = MockFactory.createUtxoList(count: 5);
        Transaction tx = Transaction.forSinglePayment(
            utxos, receiveAddress, changeAddressPath, 4200, 1, vault);
        expect(tx.outputs.length, 2);
      });
      test('Generate transactin for single payment (case 2)', () {
        SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        List<Utxo> utxos = MockFactory.createUtxoList(count: 5);
        String receiveAddress = 'bcrt1q8e5ghfg8gpe4dlfv7qqck2c2jc47lnllul3puh';
        String changeAddressPath = '${vault.derivationPath}/1/0';
        Transaction tx = Transaction.forSinglePayment(
            utxos, receiveAddress, changeAddressPath, 3500, 1, vault);
        expect(tx.outputs[0].getAddress(), receiveAddress);
        expect(tx.outputs[1].getAddress(),
            vault.getAddressWithDerivationPath(changeAddressPath));
        expect(tx.outputs[0].amount, 3500);
      });
    });

    group('Transaction.forSweep', () {
      test('Generate transaction for sweep', () {
        SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        List<Utxo> utxos = MockFactory.createUtxoList(count: 5);
        String receiveAddress = 'bcrt1q8e5ghfg8gpe4dlfv7qqck2c2jc47lnllul3puh';
        Transaction tx = Transaction.forSweep(utxos, receiveAddress, 1, vault);
        int utxoTotalAmount = 0;
        for (Utxo utxo in utxos) {
          utxoTotalAmount += utxo.amount;
        }
        expect(tx.outputs[0].amount < utxoTotalAmount, true);
        expect(tx.outputs.length, 1);
      });
    });

    group('Transaction.forBatchPayment', () {
      test('Generate transaction for batch', () {
        SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        List<Utxo> utxos = MockFactory.createUtxoList(count: 5);
        Map<String, int> paymentMap = {
          'bcrt1qzf8qs6qgyq9kgu225jatvvx0nvvm3u3ka5gf7w': 1000,
          'bcrt1qwr2aleje6vh48xzh9djeap9qcnc7atf57l302c': 2000
        };
        String changeAddressPath = '${vault.derivationPath}/1/0';
        Transaction tx = Transaction.forBatchPayment(
            utxos, paymentMap, changeAddressPath, 1, vault);

        expect(tx.outputs.length == 3, isTrue);
        expect(tx.serialize().hashCode, 960424395);
      });
    });
    group('Transaction.forBatchSweep', () {
      test('Generate transaction for batch sweep', () {
        SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        List<Utxo> utxos = MockFactory.createUtxoList(count: 5);
        Map<String, int> paymentMap = {
          'bcrt1qzf8qs6qgyq9kgu225jatvvx0nvvm3u3ka5gf7w': 1000,
          'bcrt1qwr2aleje6vh48xzh9djeap9qcnc7atf57l302c': 2000
        };
        String remainderAddress =
            'bcrt1q8e5ghfg8gpe4dlfv7qqck2c2jc47lnllul3puh';
        Transaction tx = Transaction.forBatchSweep(
            utxos, paymentMap, remainderAddress, 1, vault);
        expect(tx.outputs.length == 3, isTrue);
        expect(tx.serialize().hashCode, 440536889);
        expect(tx.outputs[2].amount, 496556);
        expect(tx.outputs[2].getAddress(), remainderAddress);
      });
    });
    group('Transaction.parse', () {
      test('Generate transaction from parsing', () {
        String segwitTransactionText =
            '0100000000010126a348fa555f96162bc9e178d54dd8ebecf7f08ef20cc8415f3b4bd6756ada490300000000ffffffff035b5a2300000000001600144e778a823f6b0cd146fb9e63e33a80786c61ebc7ee5f03000000000017a914daffddf6f584eacfa1adbd88a98fdfc1e6f3510b87b4600f0000000000220020701a8d401c84fb13e6baf169d59684e17abd9fa216c8cc5b9fc63d622ff8c58d04004730440220311e2611916105cdc8b3be34ab2be50c97bebcaad598accc1c20b8244bdf3d77022072777a3754a231b57e404b94dbf7ee8d9cf20b29f35c9b310468a84aa792c1bd014730440220540695e2faab7ea0e7a54e744b2bf14234791eff4618ff74ebed481d85d0d5be02202f08aaef8b6e13dfba904d5af60811630b7dde051bec534af8008c1c6d1ff732016952210375e00eb72e29da82b89367947f29ef34afb75e8654f6ea368e0acdfd92976b7c2103a1b26313f430c4b15bb1fdce663207659d8cac749a0e53d70eff01874496feff2103c96d495bfdd5ba4145e3e046fee45e84a8a48ad05bd8dbb395c011a32cf9f88053ae00000000';
        String legacyTransactionText =
            '0200000004076b731f18a90c9ecfddec457decee3eaeb1b8919d8a993c53e339c2fd9e2b3e000000006b483045022100b4931427c733c2d966e2047226469540b8463d3e601b8f376fa4664ea2105920022043583f021048c649fbe52e83b1be9d4bfc87f64f75b07234f89327a794fd5ffc0121028fa220c9e1ea20d9564d96c8b6732691481883053bb69b87d4e979d16a285f54feffffff28d4197e9bfd01ca7bebb531c78ead18dff10c15b8f69b83eb1d2bd5817434cc010000006a47304402207317915f68dd601b78ff54ae5020ba4f6bdb14fab3071db79810678e8a48154f02202241f2c98a88965245b2623de611bc872f66f83e787de947772442071919843e0121034564c0bb191c40947afaead343e8a23ce4709a55d36a79bc44cf9909a15be5abfeffffff4ecab342f8478707e05d5eda43f9738c0bed2f31986722479ee8bb9b8c83866e000000006a473044022025af63029d9fa3f6b5b2a4ee7ee3a4563d70a721b9c606a461be97f648fd616202206483cd4078c2f6fc261ea0ec08581c8c7889e4cbf13714ad5a35b7e9010d14ab0121038473783342f751e23f672097116dd7c21d31b90e1b43aa9dcae31d0a0cc0dea4feffffff876c02d5fac718b2532e05a7cea386c9dc32796f6d569985bd1e6432bca4625d2c0000006a473044022041ff4f0d07abcf787ae5eca10827309b93aa0a6dda18d4728ecdf7afd30c674a02204fa0f18d448bfe37b83cefe238762e9b7d9bd557b72e4ba9a4afcccc8538bbfb012103839e5fba93a076683653ec02fb760046ecf161a9997726e0cdbca17293245ebdfeffffff0243420f00000000001976a914387e98494a92c2cf642b38ecbc7bbdfdb2900da588ac63351000000000001976a91462ef8a1fd034ac03705ad25899c6e1c4374e32de88ac9e730d00';
        expect(Transaction.parse(segwitTransactionText), isA<Transaction>());
        expect(Transaction.parse(legacyTransactionText), isA<Transaction>());
      });
      test('Generate coinbase transaction from parsing', () {
        String coinbaseTransactionText =
            '020000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff5d0394da0d042e2c8b682f466f756e6472792055534120506f6f6c202364726f70676f6c642ffabe6d6d2fd95717b199f4ced43e66458da34d72329ef29a4ec90e4c7a3dfc25e678886c010000000000000016fd47150000200943279900ffffffff0488e2ff12000000002200207086320071974eef5e72eaa01dd9096e10c0383483855ea6b344259c244f73c20000000000000000266a24aa21a9edbd4202bdce00d84bdc744d65ef7fe4b8ea70bbd7780d41aeb160703a498c149200000000000000002f6a2d434f524501a898e2f126b642d6e401bdcb79979c691a8fd90de6d18fda214e5b9f350ffc7b6cf3058b9026e76500000000000000002b6a2952534b424c4f434b3a1c99338ef341e97c36cc02082199932ed689744071a0e141b5767316007794a50120000000000000000000000000000000000000000000000000000000000000000000000000';
        expect(Transaction.parse(coinbaseTransactionText), isA<Transaction>());
      });
    });
    group('Transaction.parseUnsignedTransaction', () {
      test('Generate unsigned transaction from parsing', () {
        String transactionText =
            '02000000000105f350552c40f031b89f88b71f5b358f6449a489296775f96d9a0110f9562d3a390000000000ffffffff64707f50c099875d92cf4a8aec9a6883501bd692251226085bccf9cd892289760000000000ffffffff5f0cd93abafa0cbfcc78053c7a2146349db00ebb9b6584cc965741a9ff2c075c0000000000ffffffff94f2ddc4e19a413dfce0220777c044bc35beb8e3e50418560aab2285cdc1454b0000000000fffffffffc520bd6a2585b695369f809dd856e800f953422f3f02ab0800eda352a2f33bc0000000000ffffffff01a29f0700000000001600143e688ba507407356fd2cf0018b2b0a962befcfff000000000000000000';
        expect(Transaction.parse(transactionText), isA<Transaction>());
      });
    });
    group('setOutputDerivationPath', () {
      test('sets the path only on the matching output', () {
        final target = segwitTransaction.outputs.first;
        final other = segwitTransaction.outputs.last;
        final path = "m/84'/1'/0'/1/7";

        segwitTransaction.setOutputDerivationPath(target.getAddress(), path);

        expect(target.derivationPath, path);
        expect(other.derivationPath, isNot(path));
      });
    });
    group('serialize', () {
      test('Serialize segwit transaction', () {
        String segwitTransactionText =
            '0100000000010126a348fa555f96162bc9e178d54dd8ebecf7f08ef20cc8415f3b4bd6756ada490300000000ffffffff035b5a2300000000001600144e778a823f6b0cd146fb9e63e33a80786c61ebc7ee5f03000000000017a914daffddf6f584eacfa1adbd88a98fdfc1e6f3510b87b4600f0000000000220020701a8d401c84fb13e6baf169d59684e17abd9fa216c8cc5b9fc63d622ff8c58d04004730440220311e2611916105cdc8b3be34ab2be50c97bebcaad598accc1c20b8244bdf3d77022072777a3754a231b57e404b94dbf7ee8d9cf20b29f35c9b310468a84aa792c1bd014730440220540695e2faab7ea0e7a54e744b2bf14234791eff4618ff74ebed481d85d0d5be02202f08aaef8b6e13dfba904d5af60811630b7dde051bec534af8008c1c6d1ff732016952210375e00eb72e29da82b89367947f29ef34afb75e8654f6ea368e0acdfd92976b7c2103a1b26313f430c4b15bb1fdce663207659d8cac749a0e53d70eff01874496feff2103c96d495bfdd5ba4145e3e046fee45e84a8a48ad05bd8dbb395c011a32cf9f88053ae00000000';
        Transaction segwitTransaction =
            Transaction.parse(segwitTransactionText);
        expect(segwitTransaction.serialize(), segwitTransactionText);
      });

      test('Serialize legacy transaction', () {
        String legacyTransactionText =
            '0200000004076b731f18a90c9ecfddec457decee3eaeb1b8919d8a993c53e339c2fd9e2b3e000000006b483045022100b4931427c733c2d966e2047226469540b8463d3e601b8f376fa4664ea2105920022043583f021048c649fbe52e83b1be9d4bfc87f64f75b07234f89327a794fd5ffc0121028fa220c9e1ea20d9564d96c8b6732691481883053bb69b87d4e979d16a285f54feffffff28d4197e9bfd01ca7bebb531c78ead18dff10c15b8f69b83eb1d2bd5817434cc010000006a47304402207317915f68dd601b78ff54ae5020ba4f6bdb14fab3071db79810678e8a48154f02202241f2c98a88965245b2623de611bc872f66f83e787de947772442071919843e0121034564c0bb191c40947afaead343e8a23ce4709a55d36a79bc44cf9909a15be5abfeffffff4ecab342f8478707e05d5eda43f9738c0bed2f31986722479ee8bb9b8c83866e000000006a473044022025af63029d9fa3f6b5b2a4ee7ee3a4563d70a721b9c606a461be97f648fd616202206483cd4078c2f6fc261ea0ec08581c8c7889e4cbf13714ad5a35b7e9010d14ab0121038473783342f751e23f672097116dd7c21d31b90e1b43aa9dcae31d0a0cc0dea4feffffff876c02d5fac718b2532e05a7cea386c9dc32796f6d569985bd1e6432bca4625d2c0000006a473044022041ff4f0d07abcf787ae5eca10827309b93aa0a6dda18d4728ecdf7afd30c674a02204fa0f18d448bfe37b83cefe238762e9b7d9bd557b72e4ba9a4afcccc8538bbfb012103839e5fba93a076683653ec02fb760046ecf161a9997726e0cdbca17293245ebdfeffffff0243420f00000000001976a914387e98494a92c2cf642b38ecbc7bbdfdb2900da588ac63351000000000001976a91462ef8a1fd034ac03705ad25899c6e1c4374e32de88ac9e730d00';
        Transaction tx = Transaction.parse(legacyTransactionText);
        expect(tx.serialize(), legacyTransactionText);
      });
    });
    group('getSigHash', () {
      test('Get segwit sighash', () {
        Transaction tx = Transaction.parse(
            '0100000002fff7f7881a8099afa6940d42d1e7f6362bec38171ea3edf433541db4e4ad969f0000000000eeffffffef51e1b804cc89d182d279655c3aa89e815b1b309fe287d9b2b55d57b90ec68a0100000000ffffffff02202cb206000000001976a9148280b37df378db99f66f85c95a783a76ac7a6d5988ac9093510d000000001976a9143bde42dbee7e4dbe6a21b2d50ce2f0167faa815988ac11000000',
            isEmptySignature: true);
        TransactionOutput utxo2 = TransactionOutput(
            Converter.intToLittleEndianBytes(600000000, 8),
            ScriptPublicKey.parse(
                '1600141d0f172a0ecb48aee1be1f2687d2963ae33f71a1'));

        String sigHash2 = tx.getSigHash(1, utxo2, AddressType.p2wpkh);
        expect(sigHash2,
            'c37af31116d1b27caf68aae9e3ac82f1477929014d5b917657d0eb49478cb670');
      });
      test('Get legacy sighash', () {
        Transaction transaction = Transaction.parse(
            '010000000151b8b4228ece5c5895e57a46d462381b1171c05b0ae4e804213c0f89ce6a2eee010000006b4830450221008007f1f3b5d2446a5ab5af2cf462c60a4b5c8b333921760516a2f1c34ceb50490220364d8ac8d7e5215b311bf049748714b0f27837dbfe4aae0098fd74d817ed5f32012102671f1ae5ef3966dc547de554cccf34a0aaf1f245be325ca00dc54934f10736f30000008002d0c8480000000000160014a8ae93d3a541b120756eadd49b8b52eba2796e99ad45f900000000001976a91456c0bc2f50bc150d4ea122e66db7c48b01b9722988ac00000000',
            isEmptySignature: true);
        TransactionOutput utxo1 = TransactionOutput(
            Converter.intToLittleEndianBytes(21146336, 8),
            ScriptPublicKey.parse(
                '1976a91456c0bc2f50bc150d4ea122e66db7c48b01b9722988ac'));

        String sigHash = transaction.getSigHash(0, utxo1, AddressType.p2pkh);
        expect(sigHash,
            'b895e8018fe25df450f604c6cd93db1bbf4b1a4eefc3a67ebd2de68a0b908236');
      });
    });
    group('getTaprootSigHash', () {
      test('Get taproot sighash', () {
        Transaction tx = Transaction.parse(
            '020000000001019b17422115ffae89c52a1d30a3b06ca23c2cc33755a714243151dc6fa73320600100000000ffffffff02881300000000000022512033a2310b5332888679eb9895a6b7297d6fd94620695f38ab98beb17c8b170d146c3d000000000000225120daaf3b1d59ca6401fda16d0bc787bf9fd9cb0d45b2294b95224981585cb343cd0140db7b6b9ddc1c58a43d5f6acb1cefb9ee8edac6e52af62fd616ba5781fef4f01137089880e27568fe7c72db4fc71c14bce4fb70a01c0cdd7567ccafea4e9416f400000000');
        Transaction prevTx = Transaction.parse(
            '02000000000101daf6dcbf7314137242e25895b13a7dc38968b33339b92416aea10b667c8d09570000000000feffffff02c3eca33144010000225120871f4bef9f9a4345c20db6c61cc4a6a2379d2623a76afb8f1aee18365de63504085200000000000022512001826f5d42f01744aa419ec6f32881fa7fe128391a2f626db06fc794fb9bc3c20140ade3827861cc2b900faab5588600aa641f3e8636b78bfa1fb7956575ff52dd84488e9a5434d10276179986254bfd9ff080d893f98eb05b528b0b8d8e918a3b2b693b0100');
        expect(tx.getTaprootSigHash(0, [prevTx.outputs[1]]),
            '8364138de492df088fc493cb05f99789357cbe39ad3dbf60917117b3060b7f5b');
      });
    });

    group('validateEcdsa', () {
      test('Validate signature of transaction', () {
        String transactionText =
            '020000000001016520eede29c5e034036a461980149268e263fed8a5b8e527ead8862123e3906b01000000000100000001f82a00000000000016001473f7aa4db6847eab27c59214f6ed7254627e7de002483045022100f369a3e1bdfb62a3ff875fa60bc9834326dead789a24ffcb2faf5f48628240e8022014cc216309a8ded296597cfd2680528729c0a55e43826d8af7d160d45be3df860121033b0492bf5c0a0222a55cdea04cdc022b1751112381ae6e9970319b3d6b161db900000000';
        Transaction tx = Transaction.parse(transactionText);
        String prevTxText =
            '02000000000101b388ce3d349385311d8c6e90217e206a66d30acb191369145779c2700a4a3d850000000000fdffffff0223e7141200000000160014c9d118b800a191f330e805dde37906bd8f703a8f042d000000000000160014cb325c29ac1d9f9c56ab77c7f659f6a304a7bd020247304402206c32ce7dce76088fdb81c36bba110ae4add38ecebff7ae03c36308293a0df97902203f78de99e909195bf0a8149650aed533ebab61c98be4d6adb886463dd550e3ff012102c78711069178ff17d77be53a7acedbbacac4daca293e42c61f7303362108fd2265052b00';
        Transaction prevTx = Transaction.parse(prevTxText);
        TransactionOutput utxo = prevTx.outputs[1];
        expect(tx.validateEcdsa(0, utxo), true);
      });
      test('Validate signature of transaction (false)', () {
        String transactionText =
            '020000000001016520eede29c5e034036a461980149268e263fed8a5b8e527ead8862123e3906b01000000000100000001f82a00000000000016001473f7aa4db6847eab27c59214f6ed7254627e7de002483045022100f369a3e1bdfb62a3ff875fa60bc9834326dead789a24ffcb2faf5f48628240e8022014cc216309a8ded296597cfd2680528729c0a55e43826d8af7d160d45be3df860121033b0492bf5c0a0222a55cdea04cdc022b1751112381ae6e9970319b3d6b161db900000000';
        Transaction tx = Transaction.parse(transactionText);
        String prevTxText =
            '02000000000101670c2a20b939d70170af0fc3be6e4baecf9a003df9b25ac64d3b0d18b43dc12b0200000000fdffffff033f3fc0380000000022512051db6dd7e0ceb9a4b189078555bffbeebd589d6237813b9c74bc457997c21d60e803000000000000160014cb325c29ac1d9f9c56ab77c7f659f6a304a7bd02960f000000000000225120eabe98a28e805ba56a0bce762af410f3998ee10e4c919d964dc91cf096f5a9cf0140875bc3d6e6f00d6020c095f5cc20744a1bf6ebb7bd2dbee415b8346024c6db13b1389809468d2deb6ce221c27b5bdc58a38a4a91909b5f6ac3fea26abe184347570b2b00';
        Transaction prevTx = Transaction.parse(prevTxText);
        TransactionOutput utxo = prevTx.outputs[1];
        expect(tx.validateEcdsa(0, utxo), false);
      });
    });
    group('validateSchnorr', () {
      test('Validate taproot signature of transaction', () {
        Transaction tx = Transaction.parse(
            '020000000001019b17422115ffae89c52a1d30a3b06ca23c2cc33755a714243151dc6fa73320600100000000ffffffff02881300000000000022512033a2310b5332888679eb9895a6b7297d6fd94620695f38ab98beb17c8b170d146c3d000000000000225120daaf3b1d59ca6401fda16d0bc787bf9fd9cb0d45b2294b95224981585cb343cd0140db7b6b9ddc1c58a43d5f6acb1cefb9ee8edac6e52af62fd616ba5781fef4f01137089880e27568fe7c72db4fc71c14bce4fb70a01c0cdd7567ccafea4e9416f400000000');
        Transaction prevTx = Transaction.parse(
            '02000000000101daf6dcbf7314137242e25895b13a7dc38968b33339b92416aea10b667c8d09570000000000feffffff02c3eca33144010000225120871f4bef9f9a4345c20db6c61cc4a6a2379d2623a76afb8f1aee18365de63504085200000000000022512001826f5d42f01744aa419ec6f32881fa7fe128391a2f626db06fc794fb9bc3c20140ade3827861cc2b900faab5588600aa641f3e8636b78bfa1fb7956575ff52dd84488e9a5434d10276179986254bfd9ff080d893f98eb05b528b0b8d8e918a3b2b693b0100');
        expect(tx.validateSchnorr(0, [prevTx.outputs[1]]), true);
      });
    });
    group('getVirtualByte', () {
      test('Get virtual byte', () {
        expect(legacyTransaction.getVirtualByte(), 188.0);
        expect(segwitTransaction.getVirtualByte(), 140.5);
      });
      test('Test with tx', () {
        String txText =
            '0200000000010168414056047da922de8c3f8c671f0668907e29be197ac4c76e0dc2673355dc9b0000000000ffffffff02a086010000000000160014d3cf7bce6a9c341feaca1f20cb42cf440e5bef7a207a3b0000000000160014e29982768e6a80d5034191ffadc33a9da0b22f2c02483045022100e56b4ea67ffdb53f9a42c6263e3342a7454103a5f4b2c8f25949731bb4e9ca3d02204b4008ad728b441bee68a8e5cbeb35e44de6e6de793d94c95004c04b583495e401210247592babe670e5bb9a9163f99381ec3934461ed120a57c1e96669f6db314552d00000000';
        Transaction tx = Transaction.parse(txText);
        expect(tx.getVirtualByte(), 140.5);
      });
    });
    group('estimateVirtualByte', () {
      test('Get estimated virtyal byte', () {
        SingleSignatureVault vault = MockFactory.createP2wpkhVault();
        List<Utxo> utxos = MockFactory.createUtxoList(count: 5);
        String receiveAddress = 'bcrt1q8e5ghfg8gpe4dlfv7qqck2c2jc47lnllul3puh';
        String changeAddressPath = '${vault.derivationPath}/1/0';
        Transaction tx = Transaction.forBatchPayment(
            utxos, {receiveAddress: 4200}, changeAddressPath, 1, vault);
        expect(tx.estimateVirtualByte(AddressType.p2wpkh), 412.75);
      });
      test('Get estimated virtual byte in p2tr key path spending', () {
        TaprootVault vault = MockFactory.createP2trKeyPathSpendingVault();
        List<Utxo> utxos = MockFactory.createUtxoList(count: 1);
        Transaction tx = Transaction.forSweep(
            utxos,
            'bc1p5fdr2ht0y4rjckn869skpml7pulm8wx6lu4c5eezwngx3c3uupzssx4myf',
            1,
            vault);
        expect(tx.estimateVirtualByte(AddressType.p2tr), 111.25);
      });
      test('Get estimated virtual byte in musig2 spending', () {
        late KeyStore keyStore1;
        late KeyStore keyStore2;
        late TaprootVault vault;

        NetworkType.setNetworkType(NetworkType.regtest);

        SingleSignatureVault vault1 =
            MockFactory.createP2wpkhVault(passphrase: 'A');
        SingleSignatureVault vault2 =
            MockFactory.createP2wpkhVault(passphrase: 'B');

        keyStore1 = KeyStore.fromSeed(vault1.keyStore.seed, AddressType.p2tr);
        keyStore2 = KeyStore.fromSeed(vault2.keyStore.seed, AddressType.p2tr);

        int addressIndex = 1;

        vault = TaprootVault.fromKeyStoreList([keyStore1, keyStore2], []);

        Utxo utxo = Utxo(
            '5786f8eda5a9b882d35b5116d1fae71256f4f0d8b799bc45bb1b4fdbf86c79df',
            0,
            21000,
            "m/86'/1'/0'/0/$addressIndex");
        Transaction tx = Transaction.forSinglePayment([utxo],
            MockFactory.reveiveAddress, "m/86'/1'/0'/1/0", 1000, 3, vault);
        expect(tx.estimateVirtualByte(AddressType.p2tr), 142.25);
      });

      test('Get estimated virtual byte in p2tr script path spending', () {
        TaprootVault parentVault = MockFactory.createP2trVaultWithPolicies();
        TaprootVault childVault =
            MockFactory.createBeneficiaryVault(passphrase: 'C');
        TaprootVault beneficiaryVault =
            TaprootVault.fromDescriptor(parentVault.descriptor);
        beneficiaryVault
            .bindSeedToBeneficiaryKeyStore(childVault.keyStoreList[0].seed);
        int addressIndex = 1;
        expect(parentVault.getAddress(addressIndex),
            'bcrt1p0jtzj2ukjewq7x20kl8g6zq3aph5sq3v2lf6nnfzqu9n9ft4u8pqu7yysc');
        // Create a coherent funding tx and spend its output via script path.

        Utxo utxo = Utxo(
            '4518033c0c22e2fafd5779d5f5c4e4df4849730581d5d93658de18444b1080d6',
            1,
            21000,
            "m/86'/1'/0'/0/$addressIndex");

        Transaction tx = Transaction.forSinglePayment(
            [utxo],
            MockFactory.reveiveAddress,
            "m/86'/1'/0'/1/0",
            20000,
            1,
            beneficiaryVault);
        tx.setPolicy(beneficiaryVault.getSpendablePolicy());
        expect(
            tx.estimateVirtualByte(AddressType.p2tr,
                leafCount: parentVault.policyList.length),
            169.25);
      });

      test('Create p2tr script path transaction with policy fee', () {
        TaprootVault parentVault = MockFactory.createP2trVaultWithPolicies();
        TaprootVault childVault =
            MockFactory.createBeneficiaryVault(passphrase: 'C');
        TaprootVault beneficiaryVault =
            TaprootVault.fromDescriptor(parentVault.descriptor);
        beneficiaryVault
            .bindSeedToBeneficiaryKeyStore(childVault.keyStoreList[0].seed);

        Utxo utxo = Utxo(
            '4518033c0c22e2fafd5779d5f5c4e4df4849730581d5d93658de18444b1080d6',
            1,
            21000,
            "m/86'/1'/0'/0/1");

        Transaction tx = Transaction.forSinglePayment(
            [utxo],
            MockFactory.reveiveAddress,
            "m/86'/1'/0'/1/0",
            20000,
            1,
            beneficiaryVault,
            policy: beneficiaryVault.getSpendablePolicy());
        expect(
            tx.estimateVirtualByte(AddressType.p2tr,
                leafCount: parentVault.policyList.length),
            169.25);
        expect(tx.outputs[1].amount, 830);
      });
    });
    group('estimateFee', () {
      test('Get estimated fee', () {
        TransactionInput input = TransactionInput.parse(
            'a463a7a78daffa1bdb1248121adb14b94f70a1fabffc81637f4049c3d65cc69f000000000000000080');
        TransactionOutput output1 = TransactionOutput.parse(
            'e803000000000000160014b247a00acc1cc2c0b4be0d3c38d866f9c08d244a');
        TransactionOutput output2 = TransactionOutput.parse(
            '051f000000000000160014d32c7c4dbb9457cff124c786bac87a9a706c5b3a');
        Transaction tx = Transaction.withInputsAndOutputs(
            [input], [output1, output2], AddressType.p2wpkh);
        expect(tx.estimateFee(1, AddressType.p2wpkh), 141);
      });
    });
    group('addInputWithUtxo', () {
      SingleSignatureVault vault = MockFactory.createP2wpkhVault();
      List<Utxo> utxos = MockFactory.createUtxoList(count: 5);
      String receiveAddress = 'bcrt1q8e5ghfg8gpe4dlfv7qqck2c2jc47lnllul3puh';
      String changeAddressPath = '${vault.derivationPath}/1/0';
      double feeRate = 2.0;
      test('Add input with utxo', () {
        Transaction tx = Transaction.forSinglePayment(utxos.sublist(0, 1),
            receiveAddress, changeAddressPath, 3200, feeRate, vault);
        int beforeInputLength = tx.inputs.length;

        tx.addInputWithUtxo(utxos[4], feeRate, vault);

        int afterInputLength = tx.inputs.length;

        int inputAmount = 0;
        for (Utxo u in tx.utxoList) {
          inputAmount += u.amount;
        }
        int outputAmount = 0;
        for (TransactionOutput output in tx.outputs) {
          outputAmount += output.amount;
        }

        expect(afterInputLength, beforeInputLength + 1);
        expect(
            inputAmount >=
                outputAmount + tx.estimateFee(feeRate, vault.addressType),
            true);
      });
    });
    group('removeInputWithUtxo', () {
      SingleSignatureVault vault = MockFactory.createP2wpkhVault();
      List<Utxo> utxos = MockFactory.createUtxoList(count: 5);
      String receiveAddress = 'bcrt1q8e5ghfg8gpe4dlfv7qqck2c2jc47lnllul3puh';
      String changeAddressPath = '${vault.derivationPath}/1/0';
      double feeRate = 2.0;
      test('Remove utxo in dust change case', () {
        Transaction tx = Transaction.forBatchPayment(utxos.sublist(0, 4),
            {receiveAddress: 299300}, changeAddressPath, feeRate, vault);
        int beforeInputLength = tx.inputs.length;

        tx.removeInputWithUtxo(utxos[3], feeRate, vault);
        int afterInputLength = tx.inputs.length;
        int inputAmount = 0;
        for (Utxo u in tx.utxoList) {
          inputAmount += u.amount;
        }
        int outputAmount = 0;
        for (TransactionOutput output in tx.outputs) {
          outputAmount += output.amount;
        }
        expect(afterInputLength, beforeInputLength - 1);
        expect(tx.outputs.length, 1);
        expect(
            inputAmount >=
                outputAmount + tx.estimateFee(feeRate, vault.addressType),
            true);
      });
    });
    group('updateFeeRate', () {
      SingleSignatureVault vault = MockFactory.createP2wpkhVault();
      List<Utxo> utxos = MockFactory.createUtxoList(count: 5);
      String receiveAddress = 'bcrt1q8e5ghfg8gpe4dlfv7qqck2c2jc47lnllul3puh';
      String changeAddressPath = '${vault.derivationPath}/1/0';
      test('Reject negative and non-finite fee rates', () {
        final Transaction tx = Transaction.forBatchPayment(utxos.sublist(0, 4),
            {receiveAddress: 24000}, changeAddressPath, 1, vault);

        for (final double feeRate in <double>[
          -1,
          double.nan,
          double.infinity
        ]) {
          expect(() => tx.updateFeeRate(feeRate, vault), throwsArgumentError);
        }
      });

      test('Lower fee rate', () {
        double beforeFeeRate = 4;
        double afterFeeRate = 2;
        Transaction tx = Transaction.forBatchPayment(utxos.sublist(0, 4),
            {receiveAddress: 24000}, changeAddressPath, beforeFeeRate, vault);

        int beforeChange = tx.outputs[1].amount;

        tx.updateFeeRate(afterFeeRate, vault);
        int afterChange = tx.outputs[1].amount;
        expect(afterChange > beforeChange, true);
      });

      test('Higher fee rate', () {
        double beforeFeeRate = 2;
        double afterFeeRate = 4;
        Transaction tx = Transaction.forBatchPayment(utxos.sublist(0, 4),
            {receiveAddress: 240000}, changeAddressPath, beforeFeeRate, vault);
        int beforeChange = tx.outputs[1].amount;

        tx.updateFeeRate(afterFeeRate, vault);
        int afterChange = tx.outputs[1].amount;

        expect(afterChange < beforeChange, true);
      });
      test('Higher fee rate and dust threshold', () {
        double beforeFeeRate = 2;
        double afterFeeRate = 5;

        Transaction tx = Transaction.forBatchPayment(utxos.sublist(0, 4),
            {receiveAddress: 398200}, changeAddressPath, beforeFeeRate, vault);
        int sendingAmount = tx.outputs[0].amount;

        tx.updateFeeRate(afterFeeRate, vault);
        int inputAmount = 0;
        int outputAmount = 0;
        for (TransactionOutput output in tx.outputs) {
          outputAmount += output.amount;
        }
        for (Utxo u in tx.utxoList) {
          inputAmount += u.amount;
        }
        expect(tx.outputs.length, 1);
        expect(tx.outputs[0].amount, sendingAmount);
        expect(
            inputAmount >=
                outputAmount + tx.estimateFee(afterFeeRate, vault.addressType),
            true);
      });
      test('For sweep case', () {
        double beforeFeeRate = 2;
        double afterFeeRate = 1;

        Transaction tx = Transaction.forSweep(
            utxos.sublist(0, 1), receiveAddress, beforeFeeRate, vault);
        double beforeTotalOutput = 0;
        for (TransactionOutput output in tx.outputs) {
          beforeTotalOutput += output.amount;
        }

        int beforeSendindAmount = tx.outputs[0].amount;

        tx.updateFeeRate(afterFeeRate, vault);

        double afterTotalOutput = 0;
        for (TransactionOutput output in tx.outputs) {
          afterTotalOutput += output.amount;
        }

        int afterSendAmount = tx.outputs[0].amount;

        expect(tx.outputs.length, 1);
        expect(beforeSendindAmount < afterSendAmount, true);
        expect(beforeTotalOutput < afterSendAmount, true);
        expect(beforeTotalOutput < afterTotalOutput, true);
      });
    });
  });
}
