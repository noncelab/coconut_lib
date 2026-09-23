@Tags(['unit'])
library;

import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('TaprootVault', () {
    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
    });

    group('fromKeyStoreList', () {
      test('creates vault', () {
        final vault = TaprootVault.fromKeyStoreList(
            [KeyStoreFixture.common(AddressType.p2tr)], []);
        expect(vault.keyStoreList.length, 1);
        expect(vault.getAddress(0).startsWith('bcrt1p'), true);
      });

      test('creates vault with policies', () {
        InheritancePolicy policy1 = InheritancePolicy.fromDescriptorAndLocktime(
            WalletFixture.beneficiaryVault(passphrase: 'A').descriptor,
            1767225600);
        InheritancePolicy policy2 = InheritancePolicy.fromDescriptorAndLocktime(
            WalletFixture.beneficiaryVault(passphrase: 'B').descriptor,
            1767225600);
        final vault = TaprootVault.fromKeyStoreList(
            [KeyStoreFixture.common(AddressType.p2tr)], [policy1, policy2]);
        expect(vault.keyStoreList.length, 1);
        expect(vault.getAddress(0).startsWith('bcrt1p'), true);
      });
      test('check policy order', () {
        InheritancePolicy policy1 = InheritancePolicy.fromDescriptorAndLocktime(
            WalletFixture.beneficiaryVault(passphrase: 'A').descriptor,
            1767225600);
        InheritancePolicy policy2 = InheritancePolicy.fromDescriptorAndLocktime(
            WalletFixture.beneficiaryVault(passphrase: 'B').descriptor,
            1767225600);
        final vault1 = TaprootVault.fromKeyStoreList(
            [KeyStoreFixture.common(AddressType.p2tr)], [policy1, policy2]);
        final vault2 = TaprootVault.fromKeyStoreList(
            [KeyStoreFixture.common(AddressType.p2tr)], [policy2, policy1]);
        expect(vault1.getAddress(0), vault2.getAddress(0));
      });

      // A policy list carries no shape, so this factory picks one: leaves are
      // paired left to right and an odd leaf is promoted, giving {{A,B},C}.
      // The shape decides the merkle root and so the address, which is why
      // these are pinned.
      const Map<int, String> addressByLeafCount = {
        1: 'bcrt1pavh0uat5qg4auj7teew4lqp3e23plc75mpm5u6lmhlf9hjkex7zqqssw8v',
        2: 'bcrt1peranau8uzwpwd0u098ez6vprj56335ty9wjjm4lwtsm5lj6kfytq48nf9m',
        3: 'bcrt1p2zvzpewe3xeeewd9r06vknmpmcqa37mtlzazkdn7pldpewkhmces9040hn',
        4: 'bcrt1pyjfvcscnzqjhf4juc48khs2ph9lpapfadj80jx76hku6l9tha9rq39l2wz',
        5: 'bcrt1pehtygfw3q7uy3quryvxhct2wddtca754pdxrrd5agkylq48asuvswyla0p',
      };

      addressByLeafCount.forEach((leafCount, address) {
        test('$leafCount leaves keep the default grouping', () {
          expect(_defaultGroupingVault(leafCount).getAddress(0), address);
        });
      });

      test('default grouping keeps its control blocks', () {
        final vault = _defaultGroupingVault(3);
        expect(vault.getControlBlock(0, 0),
            'c0747e81d295fddc5fba77c1f6fb6d7d6eeef12f05ba72438f0a966d969210ed79c731f2857b160fb42003ab6d6d9da64697b48bba8f3bd94ac7844cfb87d3f757ce8a49424c61c54372e3fc47441de31fd78468815b4e6c686d9be693c0637b2d');
        expect(vault.getControlBlock(1, 0),
            'c0747e81d295fddc5fba77c1f6fb6d7d6eeef12f05ba72438f0a966d969210ed795af3b38875088bdc42f611e51a8b11140be00a28415f8b27f5467bc290937c45ce8a49424c61c54372e3fc47441de31fd78468815b4e6c686d9be693c0637b2d');
        // The promoted leaf is one sibling closer to the root.
        expect(vault.getControlBlock(2, 0),
            'c0747e81d295fddc5fba77c1f6fb6d7d6eeef12f05ba72438f0a966d969210ed792299037125304dfefd69fd0cd0c8e404b38979379d7fefb7c45118ceb1b3523c');
      });

      test('matches the tree TapTree builds from the same policies', () {
        final vault = _defaultGroupingVault(3);
        expect(vault.tapTree!.toTreeExpression(),
            TapTree.fromPolicies(vault.policyList)!.toTreeExpression());
      });
    });

    group('fromTapTree', () {
      // {A,{B,C}}: A alone on one side, B and C paired on the other.
      TaprootVault rightLeaningVault() => TaprootVault.fromTapTree(
          [KeyStoreFixture.common(AddressType.p2tr, passphrase: 'internal')],
          TapBranch(TapLeaf(_leaf('A')),
              TapBranch(TapLeaf(_leaf('B')), TapLeaf(_leaf('C')))));

      test('{A,{B,C}} and {{A,B},C} are different addresses', () {
        final rightLeaning = rightLeaningVault();
        final leftLeaning = TaprootVault.fromTapTree(
            [KeyStoreFixture.common(AddressType.p2tr, passphrase: 'internal')],
            TapBranch(TapBranch(TapLeaf(_leaf('A')), TapLeaf(_leaf('B'))),
                TapLeaf(_leaf('C'))));

        expect(rightLeaning.getAddress(0), isNot(leftLeaning.getAddress(0)));
        expect(
            rightLeaning.tapTree!.toTreeExpression(),
            '{${_leaf('A').toMiniscript()},'
            '{${_leaf('B').toMiniscript()},${_leaf('C').toMiniscript()}}}');
      });

      test('a branch may be written either way round', () {
        // TapBranch sorts its pair, so only the grouping moves the address.
        final swapped = TaprootVault.fromTapTree(
            [KeyStoreFixture.common(AddressType.p2tr, passphrase: 'internal')],
            TapBranch(TapBranch(TapLeaf(_leaf('B')), TapLeaf(_leaf('C'))),
                TapLeaf(_leaf('A'))));
        expect(swapped.getAddress(0), rightLeaningVault().getAddress(0));
      });

      test('leaves keep their given order, unsorted', () {
        expect(
            rightLeaningVault()
                .policyList
                .map((policy) => policy.toMiniscript())
                .toList(),
            [
              _leaf('A').toMiniscript(),
              _leaf('B').toMiniscript(),
              _leaf('C').toMiniscript()
            ]);
      });

      test('depth follows the shape', () {
        final vault = rightLeaningVault();
        expect(vault.getMerklePathLength(0, 0), 1);
        expect(vault.getMerklePathLength(1, 0), 2);
        expect(vault.getMerklePathLength(2, 0), 2);
      });

      test('the descriptor writes the nesting', () {
        final vault = rightLeaningVault();
        final tree = vault.tapTree!.toTreeExpression();

        expect(tree, startsWith('{'));
        expect(vault.descriptor, contains(',$tree)#'));
        expect(tree, contains('${_leaf('A').toMiniscript()},{'));
        expect(tree, endsWith('${_leaf('C').toMiniscript()}}}'));
      });

      test('the shape survives the descriptor', () {
        final vault = rightLeaningVault();
        final restored = TaprootWallet.fromDescriptor(vault.descriptor);

        expect(restored.getAddress(0), vault.getAddress(0));
        expect(restored.tapTree!.toTreeExpression(),
            vault.tapTree!.toTreeExpression());
        expect(restored.getControlBlock(1, 0), vault.getControlBlock(1, 0));
      });

      test('the shape survives JSON', () {
        final vault = rightLeaningVault();
        final restored = TaprootVault.fromJson(vault.toJson());

        expect(restored.getAddress(0), vault.getAddress(0));
        expect(restored.tapTree!.toTreeExpression(),
            vault.tapTree!.toTreeExpression());
      });
    });

    group('fromSeedList', () {
      test('creates vault', () {
        final vault = TaprootVault.fromSeedList(
            [SeedFixture.common(passphrase: 'A')], []);
        expect(vault.keyStoreList.length, 1);
        expect(vault.getAddress(0).startsWith('bcrt1p'), true);
      });
    });

    group('fromCoordinatorBsms', () {
      test('builds key stores from coordinator payload', () {
        final multisig = WalletFixture.p2wshVault();
        final coordinator = multisig.getCoordinatorBsms();
        final vault = TaprootVault.fromCoordinatorBsms(coordinator);
        expect(vault.keyStoreList.length, multisig.keyStoreList.length);
        expect(vault.policyList, isEmpty);
      });
    });

    group('addPublicNonce', () {
      test('returns same psbt for single-key vault', () {
        final vault = WalletFixture.p2trKeyPathVault();
        final psbt = PsbtFixture.p2trKeyPathUnsigned().serialize();
        expect(vault.addPublicNonce(psbt), psbt);
      });

      test('throws when no keyStore can sign', () {
        final vault = WalletFixture.p2trKeyPathVault();
        final psbt = PsbtFixture.p2wpkhUnsigned().serialize();
        expect(() => vault.addPublicNonce(psbt), throwsException);
      });

      test('auxRand makes the nonce reproducible', () {
        final vault = WalletFixture.p2trPolicyVault();
        final utxo = Utxo(
            '4518033c0c22e2fafd5779d5f5c4e4df4849730581d5d93658de18444b1080d6',
            1,
            21000,
            "m/86'/1'/0'/0/0");
        final tx = Transaction.forSinglePayment([utxo],
            UtxoFixture.receiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vault);
        final psbt = Psbt.fromTransaction(tx, vault).serialize();
        final aux = Uint8List.fromList(List<int>.filled(32, 0x42));

        final first = Psbt.parse(vault.addPublicNonce(psbt, auxRand: aux))
            .inputs[0]
            .muSig2PubNonces;
        final second = Psbt.parse(vault.addPublicNonce(psbt, auxRand: aux))
            .inputs[0]
            .muSig2PubNonces;
        expect(first, isNotNull);
        expect(first, second);
      });

      test('omitting auxRand keeps nonces unpredictable', () {
        final vault = WalletFixture.p2trPolicyVault();
        final utxo = Utxo(
            '4518033c0c22e2fafd5779d5f5c4e4df4849730581d5d93658de18444b1080d6',
            1,
            21000,
            "m/86'/1'/0'/0/0");
        final tx = Transaction.forSinglePayment([utxo],
            UtxoFixture.receiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vault);
        final psbt = Psbt.fromTransaction(tx, vault).serialize();

        final first =
            Psbt.parse(vault.addPublicNonce(psbt)).inputs[0].muSig2PubNonces;
        final second =
            Psbt.parse(vault.addPublicNonce(psbt)).inputs[0].muSig2PubNonces;
        expect(first, isNot(second));
      });

      test('rejects an auxRand that is not 32 bytes', () {
        final vault = WalletFixture.p2trPolicyVault();
        final utxo = Utxo(
            '4518033c0c22e2fafd5779d5f5c4e4df4849730581d5d93658de18444b1080d6',
            1,
            21000,
            "m/86'/1'/0'/0/0");
        final tx = Transaction.forSinglePayment([utxo],
            UtxoFixture.receiveAddress, "m/86'/1'/0'/1/0", 20000, 1, vault);
        final psbt = Psbt.fromTransaction(tx, vault).serialize();
        expect(
            () => vault.addPublicNonce(psbt,
                auxRand: Uint8List.fromList(List<int>.filled(31, 0))),
            throwsArgumentError);
      });
    });

    group('toJson', () {
      test('serializes vault', () {
        final vault = TaprootVault.fromDescriptor(
            WalletFixture.p2trPolicyVault().descriptor);
        expect(vault.toJson(), isNotEmpty);
      });
    });

    group('TaprootVault.fromJson', () {
      test('restores policies from serialized vault', () {
        final original = TaprootVault.fromDescriptor(
            WalletFixture.p2trPolicyVault().descriptor);
        final restored = TaprootVault.fromJson(original.toJson());
        expect(restored.keyStoreList.length, original.keyStoreList.length);
        expect(restored.policyList.length, original.policyList.length);
        expect(restored.derivationPath, original.derivationPath);
      });

      test('throws when wallet payload is passed', () {
        final wallet = TaprootWallet.fromDescriptor(
            WalletFixture.p2trPolicyVault().descriptor);
        expect(() => TaprootVault.fromJson(wallet.toJson()), throwsException);
      });
    });

    group('fromDescriptor', () {
      test('throws on non-taproot descriptor', () {
        final p2wpkh = WalletFixture.p2wpkhVault();
        expect(() => TaprootVault.fromDescriptor(p2wpkh.descriptor),
            throwsException);
      });
    });

    group('bindSeedToBeneficiaryKeyStore', () {
      test('throws when no beneficiary account key matches', () {
        final vault = WalletFixture.p2trPolicyVault();
        final otherSeed = SeedFixture.common(passphrase: 'not-matching');
        expect(() => vault.bindSeedToBeneficiaryKeyStore(otherSeed),
            throwsStateError);
      });
    });

    group('bindSeedToKeyStore', () {
      test('throws when no account key matches', () {
        final source = WalletFixture.p2trKeyPathVault();
        final watchOnly = TaprootVault.fromDescriptor(source.descriptor);
        final otherSeed = SeedFixture.common(passphrase: 'not-matching');

        expect(() => watchOnly.bindSeedToKeyStore(otherSeed), throwsStateError);
      });
    });

    group('getSpendablePolicy', () {
      test('throws when no beneficiary seed exists', () {
        final vault = WalletFixture.p2trPolicyVault();
        expect(() => vault.getSpendablePolicy(), throwsException);
      });
    });
  });
}

/// Inheritance leaf with a stable key and locktime, named A, B, C, ...
Policy _leaf(String name) => InheritancePolicy(
    KeyStoreFixture.common(AddressType.p2tr, passphrase: 'leaf $name'),
    1767225600);

/// Vault whose script tree comes from a bare policy list.
TaprootVault _defaultGroupingVault(int leafCount) =>
    TaprootVault.fromKeyStoreList(
        [KeyStoreFixture.common(AddressType.p2tr, passphrase: 'internal')],
        List.generate(leafCount, (i) => _leaf(String.fromCharCode(65 + i))));
