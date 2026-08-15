@Tags(['unit'])
library;

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

void main() {
  group('Descriptor', () {
    group('Descriptor.forSingleSignature', () {
      test('Generate p2wpkh descriptor', () {
        Descriptor descriptor = Descriptor.forSingleSignature(
            AddressType.p2wpkh,
            KeyStore.fromExtendedPublicKey(
                "vpub5ZZ1q76vi2LR9PeQDoV13u8TZwsyqKa7yBfD3GnPPvBjVU9ZnBTMkwzCHCVBZaPHDKJNEdMKo8MTyrQ9234idzSG9nHFD6hsUB8HJ14NBg7",
                "98C7D774"),
            "84'/1'/0'");

        String target =
            "wpkh([98C7D774/84'/1'/0']vpub5ZZ1q76vi2LR9PeQDoV13u8TZwsyqKa7yBfD3GnPPvBjVU9ZnBTMkwzCHCVBZaPHDKJNEdMKo8MTyrQ9234idzSG9nHFD6hsUB8HJ14NBg7/<0;1>/*)#7ra9g9d8";
        expect(descriptor, isA<Descriptor>());
        expect(descriptor.serialize(), target);
      });
    });
    group('Descriptor.forMultisignature', () {
      test('Generate p2wsh wallet descriptor', () {
        NetworkType.setNetworkType(NetworkType.mainnet);
        String desc =
            'wsh(sortedmulti(2,[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*,[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*,[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*))#x9cc762c';
        List<KeyStore> keyStoreList = [
          KeyStore.fromExtendedPublicKey(
              'xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz',
              'e50bd392'),
          KeyStore.fromExtendedPublicKey(
              'xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA',
              '906222f7'),
          KeyStore.fromExtendedPublicKey(
              'xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V',
              '476ec2dc')
        ];
        Descriptor descriptor = Descriptor.forMultisignature(
            AddressType.p2wsh, keyStoreList, "48h/0h/0h/2h", 2);
        // print(descriptor.serialize());
        expect(descriptor, isA<Descriptor>());
        expect(descriptor.serialize(), desc);
      });

      test('Reject invalid threshold and duplicate account xpub', () {
        final keyStore = KeyStore.fromExtendedPublicKey(
            'xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz',
            'e50bd392');

        expect(
            () => Descriptor.forMultisignature(
                AddressType.p2wsh, [keyStore], "48h/0h/0h/2h", 0),
            throwsArgumentError);
        expect(
            () => Descriptor.forMultisignature(
                AddressType.p2wsh, [keyStore, keyStore], "48h/0h/0h/2h", 1),
            throwsArgumentError);
      });
    });
    group('Descriptor.parse(String descriptor)', () {
      test('Parse p2wpkh descriptor', () {
        NetworkType.setNetworkType(NetworkType.testnet);
        const bip84Descriptor =
            "wpkh([38d0b5e1/84'/1'/0']vpub5TmYRnYy8ScbkG2WmearTx1DG91gJC4TM9kRTvSQjgVMGRUdx4vRUD8UHjZn8fJZfjUoBHPnVX1q5AmHJHTHw3CRtHzfK4yqMhAKS93Xb3y/<0;1>/*)#uqpyzfuf";
        final descriptor = Descriptor.parse(bip84Descriptor);
        expect(descriptor, isA<Descriptor>());
        expect(descriptor.scriptType, 'wpkh');
      });
      test('Parse p2wpkh descriptor (ignore checksum)', () {
        const bip84Descriptor =
            "wpkh([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm/0/*)";
        final descriptor =
            Descriptor.parse(bip84Descriptor, ignoreChecksum: true);
        expect(descriptor, isA<Descriptor>());
        expect(descriptor.scriptType, 'wpkh');
      });
      test('Parse p2wpkh descriptor (ignore checksum)', () {
        const bip84Descriptor =
            "wpkh([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm)";
        final descriptor =
            Descriptor.parse(bip84Descriptor, ignoreChecksum: true);
        expect(descriptor, isA<Descriptor>());
        expect(descriptor.scriptType, 'wpkh');
      });
      // test('parse nested segwit descriptor', () {
      //   String desc =
      //       'sh(wpkh([33a0cbfd/49h/0h/0h]xpub6CorSC5E8wkNboiq84Ndxvm3w4ccSA4MbEva8khZ4a5Cxk8hQYwrsJoPsmL8KsmCeFWzD4irCJdEqcd7kKRi5SAg355pTxTgHW2eVzQu2dd/<0;1>/*))#z3ulg0nr';
      //   // sh(wpkh([33a0cbfd/49h/0h/0h]xpub6CorSC5E8wkNboiq84Ndxvm3w4ccSA4MbEva8khZ4a5Cxk8hQYwrsJoPsmL8KsmCeFWzD4irCJdEqcd7kKRi5SAg355pTxTgHW2eVzQu2dd/<0;1>/*/<0;1>/*))#ghuqfgdf
      //   Descriptor descriptor = Descriptor.parse(desc);
      //   expect(descriptor, isA<Descriptor>());
      //   expect(descriptor.serialize(), desc);
      // });
      test('Parse p2wsh descriptor', () {
        String desc =
            'wsh(sortedmulti(2,[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*,[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*,[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*))#x9cc762c';
        Descriptor descriptor = Descriptor.parse(desc);
        expect(descriptor.serialize(), desc);
        expect(descriptor, isA<Descriptor>());
        expect(descriptor.serialize(), desc);
      });
      test('Reject duplicate account xpub', () {
        const expression =
            '[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*';
        const descriptor = 'wsh(sortedmulti(1,$expression,$expression))';

        expect(() => Descriptor.parse(descriptor, ignoreChecksum: true),
            throwsArgumentError);
      });
      test('Parse p2wsh descriptor (unsorted multisig)', () {
        String desc =
            'wsh(multi(2,[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*,[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*,[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*))#x9cc762c';
        expect(() => Descriptor.parse(desc, ignoreChecksum: true),
            throwsException);
      });

      test('Parse key-path descriptor', () {
        String desc =
            "tr([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm)#w3lthqat";
        Descriptor descriptor = Descriptor.parse(desc);
        expect(descriptor.serialize(), desc);
        expect(descriptor, isA<Descriptor>());
        expect(descriptor.scriptType, 'tr');
      });
      test('Parse musig2 descriptor', () {
        String desc =
            'tr(musig(sorted([e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*,[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*,[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*)))#nqypzxsf';
        Descriptor descriptor = Descriptor.parse(desc, ignoreChecksum: true);
        expect(descriptor.serialize(), desc);
        expect(descriptor, isA<Descriptor>());
      });
      test('Checksum error exception', () {
        const bip84Descriptor =
            "wpkh([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm/0/*)#tdf2kj7a";
        expect(() => Descriptor.parse(bip84Descriptor), throwsException);
      });
    });
    group('getDerivationPath', () {
      test('Get derivation path', () {
        const bip84Descriptor =
            "wpkh([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm/0/*)#tdf2kj7c";
        final descriptor = Descriptor.parse(bip84Descriptor);
        expect(descriptor.getDerivationPath(0), "m/84'/1'/0'");
      });
      test('h derivation path', () {
        const bip84Descriptor =
            "wpkh([98c7d774/84h/1h/0h]tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm/0/*)";
        final descriptor =
            Descriptor.parse(bip84Descriptor, ignoreChecksum: true);
        expect(descriptor, isA<Descriptor>());
        expect(descriptor.scriptType, 'wpkh');
        expect(descriptor.getDerivationPath(0), "m/84'/1'/0'");
      });
    });
    group('getFingerprint', () {
      test('Get fingerprint', () {
        const bip84Descriptor =
            "wpkh([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm/0/*)#tdf2kj7c";
        final descriptor = Descriptor.parse(bip84Descriptor);
        expect(descriptor.getFingerprint(0), '98c7d774');
      });
    });
    group('getPublicKey', () {
      test('Get extended public key', () {
        const bip84Descriptor =
            "wpkh([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm/0/*)#tdf2kj7c";
        final descriptor = Descriptor.parse(bip84Descriptor);
        expect(descriptor.getPublicKey(0),
            'tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm');
      });
    });
    group('serialize', () {
      test('Serialize p2wpkh', () {
        const bip84Descriptor =
            "wpkh([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm/<0;1>/*)#rha32pam";
        final descriptor = Descriptor.forSingleSignature(
            AddressType.p2wpkh,
            KeyStore.fromExtendedPublicKey(
                'tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm',
                '98c7d774'),
            "84'/1'/0'");
        String result = descriptor.serialize();
        //print(result);
        expect(result, bip84Descriptor);
      });
      test('Serialize p2wsh', () {
        String desc =
            'wsh(sortedmulti(2,[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*,[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*,[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*))#x9cc762c';
        List<String> pubList = [
          '[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*',
          '[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*',
          '[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*'
        ];
        Descriptor descriptor = Descriptor('wsh', pubList, AddressType.p2wsh,
            requiredSignatures: 2);
        expect(descriptor.serialize(), desc);
      });
      test('Serialize musig2 descriptor', () {
        String desc =
            'tr(musig(sorted([e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*,[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*,[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*)))#nqypzxsf';
        List<String> pubList = [
          '[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*',
          '[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*',
          '[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*'
        ];
        Descriptor descriptor = Descriptor('tr', pubList, AddressType.p2tr);
        expect(descriptor.serialize(), desc);
      });
    });
    group('getAddressTypeFromDescriptor', () {
      test('Get address type from descriptor', () {
        String p2wpkhDescriptor =
            "wpkh([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm/<0;1>/*)#rha32pam";
        expect(Descriptor.getAddressTypeFromDescriptor(p2wpkhDescriptor),
            AddressType.p2wpkh);
        String p2wshDescriptor =
            'wsh(sortedmulti(2,[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*,[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*,[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*))#x9cc762c';
        expect(Descriptor.getAddressTypeFromDescriptor(p2wshDescriptor),
            AddressType.p2wsh);
        String p2trKeyPathSpendingDescriptor =
            "tr([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm)#w3lthqat";
        expect(
            Descriptor.getAddressTypeFromDescriptor(
                p2trKeyPathSpendingDescriptor),
            AddressType.p2tr);
        String p2trMuSig2Descriptor =
            'tr(musig(sorted(2,[e50bd392/48h/0h/0h/2h]xpub6FPPhpChFv7pQE7D19ZNGoFcCUzmMdwEMwqGFshE7SCfBiN5YqpejTKkshCS3sawXF98w7j5YeaYmnVdcMuX4wLr2pwiUaccvb4WsF1w5Kz/<0;1>/*,[906222f7/48h/0h/0h/2h]xpub6EgRoGnrQpGy55qdvYXqCspbx3M4zwEJqqMY4Gvf8wTd927pAoiknQBWvLpk6gh1tWJErqgW6S4QDJykGedZ7ngV2TbRG25wUEpnCox9dKA/<0;1>/*,[476ec2dc/48h/0h/0h/2h]xpub6ERySjYpfyoWiREzdy5hZFjzkPWQK5GzUiPppcqdYm1qqbi5H8tpUeX93LG1MzQLn4Dj5iMwydhnFLqWvHHJk2ZHiKD9gYZh6YbVR1VQT1V/<0;1>/*)))#x9cc762c';
        expect(Descriptor.getAddressTypeFromDescriptor(p2trMuSig2Descriptor),
            AddressType.p2tr);
      });
    });
  });
}
