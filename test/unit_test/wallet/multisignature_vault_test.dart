@Tags(['unit'])
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../mock_factory.dart';

void main() {
  group('MultisignatureVault', () {
    late MultisignatureVault vault;
    setUpAll(() {
      vault = MockFactory.createP2wshVault();
    });
    group('MultisignatureVault.fromKeyStoreList', () {
      test('Generate multisignature vault from key store list', () {
        List<KeyStore> keyStoreList = vault.keyStoreList;
        MultisignatureVault targetVault =
            MultisignatureVault.fromKeyStoreList(keyStoreList, 2);

        expect(targetVault, isA<MultisignatureVault>());
        expect(vault.descriptor, targetVault.descriptor);
        expect(() => MultisignatureVault.fromKeyStoreList(keyStoreList, 4),
            throwsException);
      });

      test('Reject invalid threshold and duplicate account xpub', () {
        expect(
            () => MultisignatureVault.fromKeyStoreList(vault.keyStoreList, 0),
            throwsException);
        expect(
            () => MultisignatureVault.fromKeyStoreList(
                [vault.keyStoreList.first, vault.keyStoreList.first], 1),
            throwsException);
      });

      test('Reject duplicate derived public key', () {
        final first = vault.keyStoreList[0];
        final second = vault.keyStoreList[1];
        final keyStoreWithCollidingDerivation = KeyStore(
            second.masterFingerprint, first.hdWallet, second.extendedPublicKey);

        expect(
            () => MultisignatureVault.fromKeyStoreList(
                [first, keyStoreWithCollidingDerivation], 1),
            throwsException);
      });
    });

    group('MultisignatureVault.fromSeedList', () {
      test('Generate multisignature vault from seed list', () {
        List<Seed> seedList = [];
        for (int i = 0; i < 3; i++) {
          seedList.add(vault.keyStoreList[i].seed);
        }
        MultisignatureVault targetVault =
            MultisignatureVault.fromSeedList(seedList, 2);

        expect(targetVault, isA<MultisignatureVault>());
        expect(vault.descriptor, targetVault.descriptor);
      });

      test('Reject duplicate seed', () {
        final seed = vault.keyStoreList.first.seed;
        expect(() => MultisignatureVault.fromSeedList([seed, seed], 1),
            throwsException);
      });
    });
    group('MultisignatureVault.fromCoordinatorBsms', () {
      test('Generate multisignature vault from BSMS coordinator', () {
        MultisignatureVault targetVault =
            MultisignatureVault.fromCoordinatorBsms(vault.getCoordinatorBsms(),
                addressType: AddressType.p2wsh);

        expect(targetVault, isA<MultisignatureVault>());
        expect(vault.descriptor, targetVault.descriptor);
      });

      test('Reject duplicate account xpub in BSMS coordinator', () {
        final expression = Descriptor.getKeyOriginExpression(
            vault.keyStoreList.first, vault.derivationPath);
        final body = 'wsh(sortedmulti(1,$expression,$expression))';
        final descriptor = '$body#${Checksum.getChecksum(body)}';
        final coordinator =
            'BSMS 1.0\n$descriptor\n/0/*,/1/*\n${vault.getAddress(0)}';

        expect(() => MultisignatureVault.fromCoordinatorBsms(coordinator),
            throwsException);
      });
    });
    group('bindSeedToKeyStore', () {
      test('Bind seed to vault', () {
        MultisignatureVault targetVault =
            MultisignatureVault.fromCoordinatorBsms(vault.getCoordinatorBsms(),
                addressType: AddressType.p2wsh);
        for (int i = 0; i < targetVault.keyStoreList.length; i++) {
          expect(targetVault.keyStoreList[i].hasSeed, false);
          targetVault.bindSeedToKeyStore(vault.keyStoreList[i].seed);
          expect(targetVault.keyStoreList[i].hasSeed, true);
        }
        for (int i = 0; i < targetVault.keyStoreList.length; i++) {
          expect(vault.keyStoreList[i].seed, targetVault.keyStoreList[i].seed);
        }
      });

      test('rejects a seed that does not match an account key', () {
        final targetVault = MultisignatureVault.fromCoordinatorBsms(
            vault.getCoordinatorBsms(),
            addressType: AddressType.p2wsh);
        final otherSeed = MockFactory.getCommonSeed(passphrase: 'different');

        expect(
            () => targetVault.bindSeedToKeyStore(otherSeed), throwsStateError);
      });
    });

    group('toJson', () {
      test('serializes vault', () {
        expect(vault.toJson(), isNotEmpty);
      });
    });

    group('MultisignatureVault.fromJson', () {
      test('restores serialized vault', () {
        final seedlessKeyStores = vault.keyStoreList
            .map((e) => KeyStore.fromExtendedPublicKey(
                  e.extendedPublicKey.serialize(),
                  e.masterFingerprint,
                ))
            .toList();
        final seedlessVault = MultisignatureVault.fromKeyStoreList(
            seedlessKeyStores, vault.requiredSignature,
            addressType: vault.addressType);
        final json = seedlessVault.toJson();
        final restored = MultisignatureVault.fromJson(json);
        expect(restored.requiredSignature, seedlessVault.requiredSignature);
        expect(restored.addressType, seedlessVault.addressType);
        expect(restored.keyStoreList.length, seedlessVault.keyStoreList.length);
      });

      test('Reject duplicate account xpub in json', () {
        final seedlessKeyStores = vault.keyStoreList
            .map((keyStore) => KeyStore.fromExtendedPublicKey(
                keyStore.extendedPublicKey.serialize(),
                keyStore.masterFingerprint))
            .toList();
        final seedlessVault = MultisignatureVault.fromKeyStoreList(
            seedlessKeyStores, vault.requiredSignature,
            addressType: vault.addressType);
        final json = jsonDecode(seedlessVault.toJson()) as Map<String, dynamic>;
        json['requiredSignature'] = 1;
        json['keyStores'] = [json['keyStores'][0], json['keyStores'][0]];

        expect(() => MultisignatureVault.fromJson(jsonEncode(json)),
            throwsException);
      });
    });
  });
}
