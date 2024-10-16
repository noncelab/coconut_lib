@Tags(['integration'])
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_lib/src/utils/hash.dart';
import 'package:test/test.dart';

void main() {
  String dbDirectory = 'objectbox';
  Repository.initialize(dbDirectory);

  group('Seed test', () {
    test('Test mnemonic validation', () {
      String wrongMnemonic1 =
          'eagle hedgehog then coral type message loyal blanket hundred ritual flock zebra mammal above dial senior easy hope canoe myth neck number face abandon';
      String wrongMnemonic2 =
          'rib reward pill favorite expect elder cash patient hour bird genius myth';
      String wrongMnemonic3 =
          'wise tragic potato piece tail intact second bird ignore absent sleep attract cradle double arm';
      String wrongMnemonic4 =
          'foster across update trigger grid print choose tag water secon system town';
      expect(() => Seed.fromMnemonic(wrongMnemonic1), throwsException);
      expect(() => Seed.fromMnemonic(wrongMnemonic2), throwsException);
      expect(() => Seed.fromMnemonic(wrongMnemonic3), throwsException);
      expect(() => Seed.fromMnemonic(wrongMnemonic4), throwsException);
    });

    test('Test Mnemonic import(12 words)', () {
      String test15Mnemonic1 =
          'salmon divide print addict mule frozen behave pelican fluid wire blur renew';
      String test15Mnemonic2 =
          'bitter beach warrior chief effort stereo pilot memory afraid give parrot drum';
      String test15Mnemonic3 =
          'current demand wood crane rapid raise post question lucky bird infant rose';
      String test15Mnemonic4 =
          'slice nature blur still strong tip ignore renew tonight draw method october';
      String test15Mnemonic5 =
          'orient scout admit follow tomorrow fire verb forward note bind dad supreme';
      expect(() => Seed.fromMnemonic(test15Mnemonic1), returnsNormally);
      expect(() => Seed.fromMnemonic(test15Mnemonic2), returnsNormally);
      expect(() => Seed.fromMnemonic(test15Mnemonic3), returnsNormally);
      expect(() => Seed.fromMnemonic(test15Mnemonic4), returnsNormally);
      expect(() => Seed.fromMnemonic(test15Mnemonic5), returnsNormally);
    });

    test('Test Mnemonic import(15 words)', () {
      String test15Mnemonic1 =
          'pattern cook buzz magic glad artist matrix rural shoot spoil slow topple theory baby inside';
      String test15Mnemonic2 =
          'bullet fragile addict awesome about chapter matter box special manage diesel sausage soft bonus party';
      String test15Mnemonic3 =
          'palace debate prefer exit build basket film charge obvious funny supply scene spice ice deposit';
      String test15Mnemonic4 =
          'leaf strike pair rather gasp any arctic grape near insane boost adjust taste argue peanut';
      String test15Mnemonic5 =
          'arena control farm shallow achieve stamp naive upon east mango half depend vendor inch face';
      expect(() => Seed.fromMnemonic(test15Mnemonic1), returnsNormally);
      expect(() => Seed.fromMnemonic(test15Mnemonic2), returnsNormally);
      expect(() => Seed.fromMnemonic(test15Mnemonic3), returnsNormally);
      expect(() => Seed.fromMnemonic(test15Mnemonic4), returnsNormally);
      expect(() => Seed.fromMnemonic(test15Mnemonic5), returnsNormally);
    });

    test('Test Mnemonic import(18 words)', () {
      String testMnemonic1 =
          'fix track ecology usual control wage unable offer glare betray put resemble woman stove slice flame return brave';
      String testMnemonic2 =
          'cousin lift old feature proud enforce clarify fog about gorilla glory crop exile neck motion depth tube clown';
      String testMnemonic3 =
          'farm reward accident badge weasel acquire alter spread danger trigger today palm fatigue horse slight jump maximum amazing';
      String testMnemonic4 =
          'ankle silly census wrong seed author napkin spell worth magnet pause buffalo eagle canvas error split arrest buyer';
      String testMnemonic5 =
          'actress flat run make laptop happy sorry family toward cargo elevator suspect shallow length spare error picture bike';
      expect(() => Seed.fromMnemonic(testMnemonic1), returnsNormally);
      expect(() => Seed.fromMnemonic(testMnemonic2), returnsNormally);
      expect(() => Seed.fromMnemonic(testMnemonic3), returnsNormally);
      expect(() => Seed.fromMnemonic(testMnemonic4), returnsNormally);
      expect(() => Seed.fromMnemonic(testMnemonic5), returnsNormally);
    });
    test('Test Mnemonic import(21 words)', () {
      String testMnemonic1 =
          'erase move hello private improve spoil undo file vital reveal bench entire pass unfair horn patient layer goddess world advance identify';
      String testMnemonic2 =
          'matrix behind deer census grocery culture kick shy silent casual sail twist artwork purpose possible duck struggle never leader news flock';
      String testMnemonic3 =
          'boat super smoke tilt ginger stem refuse verb curtain adjust strategy bicycle want order column now effort unknown decline cram baby';
      String testMnemonic4 =
          'ahead deal announce seminar oyster cause mule inject example scatter welcome hair scheme speak carry pipe hat cash glimpse usual often';
      String testMnemonic5 =
          'trash vital float surface order pool special light have view crawl joy response surprise lemon pink salute yellow under intact vacuum';
      expect(() => Seed.fromMnemonic(testMnemonic1), returnsNormally);
      expect(() => Seed.fromMnemonic(testMnemonic2), returnsNormally);
      expect(() => Seed.fromMnemonic(testMnemonic3), returnsNormally);
      expect(() => Seed.fromMnemonic(testMnemonic4), returnsNormally);
      expect(() => Seed.fromMnemonic(testMnemonic5), returnsNormally);
    });
    test('Test Mnemonic import(24 words)', () {
      String testMnemonic1 =
          'second deliver box neutral keep wrap similar genuine unfold bean uncover tiger throw cook breeze illegal roof opera sea program fresh globe deputy mom';
      String testMnemonic2 =
          'drama present tongue pumpkin axis emerge warrior orient artefact motor hazard use pulse limit mother awkward right aware recipe modify peace mad mind word';
      String testMnemonic3 =
          'level city episode rail mountain lab trouble canal wash grace siren advance teach kite actor rail forget august consider best ball escape potato glue';
      String testMnemonic4 =
          'evidence whip pupil enemy invite prevent satisfy cool vote tomato palace net size offer east next glance garage subject slush ritual seat sick night';
      String testMnemonic5 =
          'middle keen caught enough inflict sock fetch dove matter envelope private chaos trend pact sea sustain little nose during voyage bargain famous wisdom chronic';
      expect(() => Seed.fromMnemonic(testMnemonic1), returnsNormally);
      expect(() => Seed.fromMnemonic(testMnemonic2), returnsNormally);
      expect(() => Seed.fromMnemonic(testMnemonic3), returnsNormally);
      expect(() => Seed.fromMnemonic(testMnemonic4), returnsNormally);
      expect(() => Seed.fromMnemonic(testMnemonic5), returnsNormally);
    });

    test('Binary entropy generation test', () {
      String wrongBin = '1111111111';
      String bin128 =
          //'10101011011010101101101010110110101011011010101101101010110110101011011010101101101010110110101011011010101101101010110110111011';
          '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111';
      String bin256 =
          '1010101101101010110110101011011010101101101010110110101011011010101101101010110110101011011010101101101010110110101011011011101110101011011010101101101010110110101011011010101101101010110110101011011010101101101010110110101011011010101101101010110110111011';
      // print(seed.mnemonic);
      expect(() => Seed.fromBinaryEntropy(wrongBin), throwsException);
      expect(Seed.fromBinaryEntropy(bin128).mnemonic,
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon attract');
      expect(Seed.fromBinaryEntropy(bin256).mnemonic,
          'problem fine pumpkin forget repeat hood survey rely hello stick problem jar repeat hood survey rely hello stick problem fine pumpkin forget report humble');
    });

    test('Test Random generation', () {
      Seed randomSeed = Seed.random(mnemonicLength: 12);
      String randomMnemonic = randomSeed.mnemonic;

      expect(() => WalletUtility.validateMnemonic(randomMnemonic),
          returnsNormally);
    });

    test('test for validating mnemonic', () {
      Seed seed12 = Seed.random(mnemonicLength: 12);
      Seed seed15 = Seed.random(mnemonicLength: 15);
      Seed seed18 = Seed.random(mnemonicLength: 18);
      Seed seed21 = Seed.random(mnemonicLength: 21);
      Seed seed24 = Seed.random(mnemonicLength: 24);

      expect(WalletUtility.validateMnemonic(seed12.mnemonic), true);
      expect(WalletUtility.validateMnemonic(seed15.mnemonic), true);
      expect(WalletUtility.validateMnemonic(seed18.mnemonic), true);
      expect(WalletUtility.validateMnemonic(seed21.mnemonic), true);
      expect(WalletUtility.validateMnemonic(seed24.mnemonic), true);
    });

    test('mnemonic word test', () {
      expect(WalletUtility.isInMnemonicWordList('abandon'), true);
      expect(WalletUtility.isInMnemonicWordList('abandon1'), false);
    });
  });

  group('HD Wallet test', () {
    test('Test get extended pubkey (BIP44)', () {
      String testSeed =
          '5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4';
      HDWallet testWallet = HDWallet.fromRootSeed(testSeed);

      String expected =
          'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj';

      expect(
          testWallet
              .derivePath("m/44'/0'/0'")
              .neutered()
              .toBase58(AddressType.p2pkh.versionForMainnet),
          expected);
    });

    test('Test get extended pubkey (BIP84)', () {
      String testSeed =
          '5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4';
      HDWallet testWallet = HDWallet.fromRootSeed(testSeed);
      String result = testWallet
          .derivePath("m/84'/0'/0'")
          .neutered()
          .toBase58(AddressType.p2wpkh.versionForMainnet);
      String expected =
          'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs';
      //print(result);
      expect(result, expected);
    });
  });

  group('AddressType test', () {
    test('test get extended pubkey (nested segwit)', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      Seed seed = Seed.fromMnemonic(
          'chaos spread coconut advance rent suggest ten vast vanish bench demand ghost');
      SingleSignatureVault vault =
          SingleSignatureVault.fromSeed(seed, AddressType.p2wpkhInP2sh);
      expect(vault.keyStore.extendedPublicKey.serialize(),
          'ypub6Xe7jrk9HdHrT6uwxRAGB1rZ72m4Nn3rWMSnv9bSSaT61qwvfD7RVNTXtyHiKnR83tdnxYKQexyniuEgU1qisfrGuQnF3sHAZE6Htam2do4');
      expect(vault.keyStore.fingerprint, '33A0CBFD');
    });

    test('get Address test (nested segwit)', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      Seed seed = Seed.fromMnemonic(
          'chaos spread coconut advance rent suggest ten vast vanish bench demand ghost');
      SingleSignatureVault vault =
          SingleSignatureVault.fromSeed(seed, AddressType.p2wpkhInP2sh);
      // print(vault.descriptor);
      SingleSignatureWallet wallet =
          SingleSignatureWallet.fromDescriptor(vault.descriptor);
      // print(wallet.getPublicKey(0));
      // print(wallet.getAddress(0));
      expect(wallet.getAddress(0), '3CJ9WbzjuiRx2GuArGMZtAW1Y7puvwjhj2');

      String pubkey =
          "03a1af804ac108a8a51782198c2d034b28bf90c8803f5a53f76276fa69a4eae77f";
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      expect(AddressType.getP2wpkhInP2shAddress(pubkey),
          '36NvZTcMsMowbt78wPzJaHHWaNiyR73Y4g');

      BitcoinNetwork.setNetwork(BitcoinNetwork.testnet);
      expect(AddressType.getP2wpkhInP2shAddress(pubkey),
          '2Mww8dCYPUpKHofjgcXcBCEGmniw9CoaiD2');
    });

    test('get Address test (p2sh)', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      String pk1 =
          '02cf0000f4001acf8844e1ca1fa8bf08d7fbf20b08b97cdab19b47313e4c4e8b86';
      String pk2 =
          '03f77a33d2dcf2ca5a60566d380433fb7bf44f3de36ed7c927fdb7ce0150ff0049';

      expect(AddressType.getP2shAddress([pk1, pk2], 2),
          '388sPAD9DSg6fcXBLapnHos38KiBntwKWD');
    });

    test('get Address test (p2wsh)', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.testnet);

      String pk1 =
          '032fd3324dac6a4e774069f270a3cfa01c4aa63076e22722071fb8209f341eb2a1';
      String pk2 =
          '0384fe8e6871fb89cbde372bc3c074dc391f01c29d081d16a1e2331a8d97ff706e';

      expect(AddressType.getP2wshAddress([pk2, pk1], 2),
          'tb1qjfj95p5r83wzvdq3mtc3rhkh00m0ucn8jl4psnknxf32mnzea4wq29xugs');
    });
  });

  group('Descriptor test', () {
    test('parse bip84 descriptor', () {
      const bip84Descriptor =
          "wpkh([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm/0/*)#tdf2kj7c";
      final descriptor = Descriptor.parse(bip84Descriptor);

      expect(descriptor.scriptType, 'wpkh');
      expect(descriptor.getFingerprint(0), '98c7d774');
      expect(descriptor.getPublicKey(0),
          'tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm');
      expect(descriptor.getDerivationPath(0), "m/84'/1'/0'");
      // print(descriptor.serialize());
    });

    test('parse (nested segwit)', () {
      String desc =
          'sh(wpkh([33a0cbfd/49h/0h/0h]xpub6CorSC5E8wkNboiq84Ndxvm3w4ccSA4MbEva8khZ4a5Cxk8hQYwrsJoPsmL8KsmCeFWzD4irCJdEqcd7kKRi5SAg355pTxTgHW2eVzQu2dd/<0;1>/*))#z3ulg0nr';
      // sh(wpkh([33a0cbfd/49h/0h/0h]xpub6CorSC5E8wkNboiq84Ndxvm3w4ccSA4MbEva8khZ4a5Cxk8hQYwrsJoPsmL8KsmCeFWzD4irCJdEqcd7kKRi5SAg355pTxTgHW2eVzQu2dd/<0;1>/*/<0;1>/*))#ghuqfgdf
      Descriptor descriptor = Descriptor.parse(desc);
      expect(descriptor.serialize(), desc);

      //final descriptor =
    });

    test('serialize bip84 descriptor(wpkh)', () {
      const bip84Descriptor =
          "wpkh([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm/<0;1>/*)#rha32pam";
      final descriptor = Descriptor.forSingleSignature(
          'wpkh',
          'tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm',
          "84'/1'/0'",
          '98c7d774');
      String result = descriptor.serialize();
      //print(result);
      expect(result, bip84Descriptor);
    });

    test('serialize descriptor(wsh)', () {
      String desc =
          'wsh(sortedmulti(2,[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*,[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*,[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*))#x9cc762c';
      List<String> pubList = [
        '[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*',
        '[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*',
        '[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*'
      ];
      Descriptor descriptor = Descriptor('wsh', pubList, requiredSignatures: 2);
      expect(descriptor.serialize(), desc);
      //final descriptor =
    });

    test('initiate descriptor(wsh)', () {
      String desc =
          'wsh(sortedmulti(2,[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*,[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*,[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*))#x9cc762c';
      List<String> pubList = [
        'xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz',
        'xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA',
        'xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V'
      ];
      Descriptor descriptor = Descriptor.forMultisignature('wsh', pubList,
          "48h/0h/0h/2h", ['e50bd392', '906222f7', '476ec2dc'], 2);
      // print(descriptor.serialize());
      expect(descriptor.serialize(), desc);
    });

    test('serialize descriptor(nested segwit)', () {
      String desc =
          'sh(wpkh([33a0cbfd/49h/0h/0h]xpub6CorSC5E8wkNboiq84Ndxvm3w4ccSA4MbEva8khZ4a5Cxk8hQYwrsJoPsmL8KsmCeFWzD4irCJdEqcd7kKRi5SAg355pTxTgHW2eVzQu2dd/<0;1>/*))#z3ulg0nr';
      List<String> pubList = [
        '[33a0cbfd/49h/0h/0h]xpub6CorSC5E8wkNboiq84Ndxvm3w4ccSA4MbEva8khZ4a5Cxk8hQYwrsJoPsmL8KsmCeFWzD4irCJdEqcd7kKRi5SAg355pTxTgHW2eVzQu2dd/<0;1>/*'
      ];
      Descriptor descriptor =
          Descriptor('sh-wpkh', pubList, requiredSignatures: 2);
      expect(descriptor.serialize(), desc);
      //final descriptor =
    });
  });

  group('Wallet base test', () {
    test('Fingerpint test', () {
      Seed seed = Seed.fromMnemonic(
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
      SingleSignatureWalletBase wb = SingleSignatureVault.fromSeed(
          Seed.fromMnemonic(seed.mnemonic), AddressType.p2wpkh);
      String result = wb.keyStore.fingerprint;
      String expected = '73C5DA0A';
      //print('result: $result');
      expect(result, expected);
    });

    test('Public key test', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      Seed seed = Seed.fromMnemonic(
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
      SingleSignatureWalletBase wb = SingleSignatureVault.fromSeed(
          Seed.fromMnemonic(seed.mnemonic), AddressType.p2wpkh);
      String result = wb.keyStore.getPublicKey(1);
      String expected =
          '03e775fd51f0dfb8cd865d9ff1cca2a158cf651fe997fdc9fee9c1d3b5e995ea77';
      expect(result, expected);
    });

    test('Address test', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      Seed seed = Seed.fromMnemonic(
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
      SingleSignatureWalletBase wb = SingleSignatureVault.fromSeed(
          Seed.fromMnemonic(seed.mnemonic), AddressType.p2wpkh);
      String result = wb.getAddress(1);
      String expected = 'bc1qnjg0jd8228aq7egyzacy8cys3knf9xvrerkf9g';
      expect(result, expected);
      //print(result);
    });

    test('segwit address validator', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      String address = 'bc1qkfr6qzkvrnpvpd97p57r3krxl8qg6fz24nzjsa';
      expect(WalletUtility.validateAddress(address), true);
      BitcoinNetwork.setNetwork(BitcoinNetwork.testnet);
      address = 'tb1q85ap5ppw3f4c604tgs6xekhsh0zeurq27939pr';
      expect(WalletUtility.validateAddress(address), true);
    });

    test('legacy address validator ', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      String address = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
      expect(WalletUtility.validateAddress(address), true);
      address = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
      expect(WalletUtility.validateAddress(address), true);
      address = '1KGG9kvV5zXiqyQAMfY32sGt9eFLMmgpgX';
      expect(WalletUtility.validateAddress(address), true);
    });

    test('taproot address validator', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.testnet);
      String address =
          'tb1pqqn6xqqp695mm0qz55fgphty39zq93s2uuuf4sy9v86jpmc6j6vqgaw90f';
      expect(WalletUtility.validateAddress(address), true);
    });

    test('get derivation path test', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      Seed seed = Seed.fromMnemonic(
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
      SingleSignatureWalletBase wb = SingleSignatureVault.fromSeed(
          Seed.fromMnemonic(seed.mnemonic), AddressType.p2wpkh);
      String result = wb.getAddress(1);
      String expected = 'bc1qnjg0jd8228aq7egyzacy8cys3knf9xvrerkf9g';
      //print(wb.getDerivationPath('bc1qnjg0jd8228aq7egyzacy8cys3knf9xvrerkf9g'));
      expect(result, expected);
      //print(result);
    });

    test('Descriptor test : segwit', () {
      const bip84Descriptor =
          "wpkh([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm/0/*)#tdf2kj7c";
      final descriptor = Descriptor.parse(bip84Descriptor);

      expect(descriptor.scriptType, 'wpkh');
      expect(descriptor.getFingerprint(0), '98c7d774');
      expect(descriptor.getPublicKey(0),
          'tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm');
      expect(descriptor.getDerivationPath(0), "m/84'/1'/0'");
    });

    test('Descriptor test : legacy', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      Seed seed = Seed.fromMnemonic(
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
      SingleSignatureWalletBase wb = SingleSignatureVault.fromSeed(
          Seed.fromMnemonic(seed.mnemonic), AddressType.p2pkh);
      String expected = '1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA';
      expect(wb.getAddress(0), expected);
    });
  });

  group('SingleSignatureWallet test', () {
    test('Test descriptor (from Vault)', () {
      String testMnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      SingleSignatureVault testVault = SingleSignatureVault.fromSeed(
          Seed.fromMnemonic(testMnemonic), AddressType.p2pkh);
      String testDescriptor = testVault.descriptor;
      // print(testDescriptor);
      String expected = testVault.keyStore.extendedPublicKey.serialize();
      // print(expected);
      SingleSignatureWallet testWallet =
          SingleSignatureWallet.fromDescriptor(testDescriptor);
      String result = testWallet.keyStore.extendedPublicKey.serialize();

      expect(result, expected);
    });
    test('Test descriptor (from String)', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      String testDescriptor =
          "pkh([73C5DA0A/44'/0'/0']xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj/0/*)#malxwzcr";
      SingleSignatureWallet testWallet =
          SingleSignatureWallet.fromDescriptor(testDescriptor);

      String expected =
          "xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj";
      String result = testWallet.keyStore.extendedPublicKey.serialize();
      expect(result, expected);
    });

    test('Test wallet Sync (from Vault)', () {
      String testMnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      SingleSignatureVault testVault = SingleSignatureVault.fromSeed(
          Seed.fromMnemonic(testMnemonic), AddressType.p2pkh);
      String descriptor = testVault.descriptor;
      String expected = testVault.keyStore.extendedPublicKey.serialize();
      SingleSignatureWallet testWallet =
          SingleSignatureWallet.fromDescriptor(descriptor);
      String result = testWallet.keyStore.extendedPublicKey.serialize();

      expect(result, expected);
    });

    test('address test', () async {
      BitcoinNetwork.setNetwork(BitcoinNetwork.testnet);
      String testMnemonic =
          'machine crack daughter fish credit glare raven fever tunnel delay fish record';
      SingleSignatureVault testVault = SingleSignatureVault.fromSeed(
          Seed.fromMnemonic(testMnemonic), AddressType.p2wpkh);
      SingleSignatureWallet wallet =
          SingleSignatureWallet.fromDescriptor(testVault.descriptor);
      expect(
          wallet.getAddress(0), 'tb1qk4z5ysfc2k72pz2ws4dhskxdq772s7uqc35dp9');
    });
  });

  group('SingleSignatureVault test', () {
    test('Test importing mnemonic', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      String testMnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      SingleSignatureVault testVault = SingleSignatureVault.fromSeed(
        Seed.fromMnemonic(testMnemonic),
        AddressType.p2pkh,
      );
      String result = testVault.keyStore.extendedPublicKey.serialize();
      String expected =
          'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj';
      //print(result);
      expect(result, expected);
    });

    test('Test random seed generation', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      SingleSignatureVault testVault = SingleSignatureVault.fromSeed(
        Seed.random(mnemonicLength: 24, passphrase: 'abc123'),
        AddressType.p2wpkh,
        accountIndex: 0,
      );
      String result = testVault.keyStore.extendedPublicKey.serialize();
      //print("derivation path: ${testVault.derivationPath}  ");
      //print(result);
      expect(result.startsWith("zpub"), true);
    });
    test('Test from entropy generation', () {
      SingleSignatureVault hexEntropySeed = SingleSignatureVault.fromSeed(
          Seed.fromHexadecimalEntropy(Hash.sha256("나실제괴로움다잊으시고")),
          AddressType.p2wpkh);
      // hex entropy = 450d5380981ebd17e120ba6f3751657fc86a010f461d45cdac8649493b2ed467
      String result = hexEntropySeed.keyStore.extendedPublicKey.serialize();
      String expected =
          'zpub6roG2Yyyd1scD5dcdVntvCUgax7pPMvNDsW7AML15vZqUvf1QA1iP1vtwwznX5rBf5yPX9EgKoVD6tMJ1SLydpvg91tjsU6e7ayQeF9APk2';
      expect(result, expected);
    });

    test('Test descriptor', () {
      String testMnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      SingleSignatureVault testVault = SingleSignatureVault.fromSeed(
          Seed.fromMnemonic(testMnemonic), AddressType.p2wpkh);
      String result = testVault.descriptor;
      String expected =
          "wpkh([73C5DA0A/84'/0'/0']zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs/<0;1>/*)#t5q024g8";
      expect(result, expected);
    });

    test('json test', () {
      String testMnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      SingleSignatureVault originVault = SingleSignatureVault.fromSeed(
          Seed.fromMnemonic(testMnemonic, passphrase: 'abc123'),
          AddressType.p2wpkh,
          accountIndex: 0);
      String json = originVault.toJson();

      // print(json);

      SingleSignatureVault vaultFromJson = SingleSignatureVault.fromJson(json);
      expect(vaultFromJson.keyStore.seed.mnemonic,
          originVault.keyStore.seed.mnemonic);
      expect(vaultFromJson.addressType, originVault.addressType);
      expect(vaultFromJson.derivationPath, originVault.derivationPath);
      expect(vaultFromJson.keyStore.seed.passphrase,
          originVault.keyStore.seed.passphrase);
      expect(
          vaultFromJson.keyStore.fingerprint, originVault.keyStore.fingerprint);
      expect(vaultFromJson.descriptor, originVault.descriptor);
    });
  });

  group('ExtendedPublicKey test', () {
    test('Test serialization', () {
      BitcoinNetwork.setNetwork(BitcoinNetwork.mainnet);
      Seed seed = Seed.fromMnemonic(
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
      SingleSignatureVault vault =
          SingleSignatureVault.fromSeed(seed, AddressType.p2wpkh);
      expect(vault.keyStore.extendedPublicKey.serialize(),
          'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs');
      expect(vault.keyStore.extendedPublicKey.parentFingerprint, '7ef32bdb');
    });
  });
}
