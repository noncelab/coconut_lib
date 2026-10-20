@Tags(['unit'])
library;

import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

/// [legacyJson] (a vault or wallet holding DROP leaves) as the old code wrote
/// it to storage.
///
/// Old versions had no `scriptForm`, wrote `type: inheritance` for the DROP
/// leaf, and spelled it `and_v(v:after(N),pk(K))` in `miniscript` and in the
/// `tapTree` expression. The leaf order and tree shape are the ones the DROP
/// leaf hashes produce, so this starts from the legacy vault and not from a
/// standard one, whose hashes order three leaves differently.
String _storedBefore(String legacyJson, {bool withTapTree = true}) {
  final Map<String, dynamic> map = jsonDecode(legacyJson);
  map['policies'] = (map['policies'] as List<dynamic>).map((dynamic p) {
    final Map<String, dynamic> policy = jsonDecode(p as String);
    policy['type'] = 'inheritance';
    policy.remove('scriptForm');
    policy['miniscript'] =
        (policy['miniscript'] as String).replaceAll('after_drop(', 'v:after(');
    return jsonEncode(policy);
  }).toList();
  if (withTapTree) {
    map['tapTree'] =
        (map['tapTree'] as String).replaceAll('after_drop(', 'v:after(');
  } else {
    map.remove('tapTree');
  }
  return jsonEncode(map);
}

void main() {
  group('inheritance policies stored before the CLTV VERIFY leaf', () {
    const int locktime = 1767225600;
    late KeyStore owner;
    late List<KeyStore> heirs;

    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
      owner = KeyStoreFixture.common(AddressType.p2tr, passphrase: 'owner');
      heirs = ['A', 'B', 'C']
          .map((name) => KeyStoreFixture.common(AddressType.p2tr,
              passphrase: 'heir $name'))
          .toList();
    });

    // What a customer funded: the DROP leaf, address derived by the old code.
    TaprootVault fundedVault(int leafCount) => TaprootVault.fromKeyStoreList([
          owner
        ], [
          for (int i = 0; i < leafCount; i++)
            LegacyInheritancePolicy(heirs[i], locktime + i)
        ]);

    // What the old code wrote to storage for the same vault.
    String storedJson(int leafCount, {bool withTapTree = true}) =>
        _storedBefore(fundedVault(leafCount).toJson(),
            withTapTree: withTapTree);

    group('Policy.fromJson', () {
      test('a stored inheritance policy without scriptForm is the DROP leaf',
          () {
        // What the old writer produced: no scriptForm.
        final Map<String, dynamic> map =
            jsonDecode(InheritancePolicy(heirs[0], locktime).toJson());
        map.remove('scriptForm');
        final String stored = jsonEncode(map);
        final Policy restored = Policy.fromJson(stored);

        expect(restored, isA<LegacyInheritancePolicy>());
        expect(
            restored.toScript(0).rawSerialize(),
            LegacyInheritancePolicy(heirs[0], locktime)
                .toScript(0)
                .rawSerialize());
      });

      test('a policy written now keeps the VERIFY leaf', () {
        final InheritancePolicy policy = InheritancePolicy(heirs[0], locktime);
        final Map<String, dynamic> map = jsonDecode(policy.toJson());
        final Policy restored = Policy.fromJson(policy.toJson());

        expect(map['scriptForm'], 'verify');
        expect(restored, isA<InheritancePolicy>());
        expect(restored, isNot(isA<LegacyInheritancePolicy>()));
        expect(restored.toScript(0).rawSerialize(),
            policy.toScript(0).rawSerialize());
      });

      test('a legacy policy written now round-trips as legacy', () {
        final LegacyInheritancePolicy policy =
            LegacyInheritancePolicy(heirs[0], locktime);

        expect(
            Policy.fromJson(policy.toJson()), isA<LegacyInheritancePolicy>());
      });
    });

    group('TaprootVault.fromJson', () {
      for (final int leafCount in [1, 2, 3]) {
        test('keeps the funded address, $leafCount leaf/leaves with tapTree',
            () {
          final TaprootVault funded = fundedVault(leafCount);
          final TaprootVault restored =
              TaprootVault.fromJson(storedJson(leafCount));

          expect(restored.policyList,
              everyElement(isA<LegacyInheritancePolicy>()));
          for (int i = 0; i < 3; i++) {
            expect(restored.getAddress(i), funded.getAddress(i));
            expect(restored.getAddress(i, isChange: true),
                funded.getAddress(i, isChange: true));
          }
        });

        test('keeps the funded address, $leafCount leaf/leaves without tapTree',
            () {
          final TaprootVault funded = fundedVault(leafCount);
          final TaprootVault restored =
              TaprootVault.fromJson(storedJson(leafCount, withTapTree: false));

          expect(restored.policyList,
              everyElement(isA<LegacyInheritancePolicy>()));
          expect(restored.getAddress(0), funded.getAddress(0));
        });
      }

      test('the old JSON does not derive the standard address', () {
        final TaprootVault standard = TaprootVault.fromKeyStoreList(
            [owner], [InheritancePolicy(heirs[0], locktime)]);
        final TaprootVault restored = TaprootVault.fromJson(storedJson(1));

        expect(restored.getAddress(0), isNot(standard.getAddress(0)));
      });

      test('re-saving a restored vault keeps the address', () {
        final TaprootVault funded = fundedVault(3);
        final TaprootVault restored = TaprootVault.fromJson(storedJson(3));
        final TaprootVault resaved = TaprootVault.fromJson(restored.toJson());

        expect(
            resaved.policyList, everyElement(isA<LegacyInheritancePolicy>()));
        expect(resaved.getAddress(0), funded.getAddress(0));
      });

      test('a vault written now with standard leaves stays standard', () {
        final TaprootVault standard = TaprootVault.fromKeyStoreList([owner],
            [for (final KeyStore h in heirs) InheritancePolicy(h, locktime)]);
        final TaprootVault restored = TaprootVault.fromJson(standard.toJson());

        expect(restored.policyList, everyElement(isA<InheritancePolicy>()));
        expect(restored.policyList,
            everyElement(isNot(isA<LegacyInheritancePolicy>())));
        expect(restored.getAddress(0), standard.getAddress(0));
      });

      test('a vault written now with legacy leaves stays legacy', () {
        final TaprootVault funded = fundedVault(3);
        final TaprootVault restored = TaprootVault.fromJson(funded.toJson());

        expect(
            restored.policyList, everyElement(isA<LegacyInheritancePolicy>()));
        expect(restored.getAddress(0), funded.getAddress(0));
      });

      test('a tree that mixes stored legacy and new standard leaves', () {
        final TaprootVault mixed = TaprootVault.fromKeyStoreList([
          owner
        ], [
          LegacyInheritancePolicy(heirs[0], locktime),
          InheritancePolicy(heirs[1], locktime + 1),
        ]);
        final TaprootVault restored = TaprootVault.fromJson(mixed.toJson());

        expect(restored.getAddress(0), mixed.getAddress(0));
        expect(
            restored.policyList.whereType<LegacyInheritancePolicy>().length, 1);
      });
    });

    group('TaprootWallet.fromJson', () {
      test('a watch-only wallet from stored JSON keeps the funded address', () {
        final TaprootVault funded = fundedVault(3);
        final String storedWallet = _storedBefore(
            TaprootWallet.fromDescriptor(funded.descriptor).toJson());
        final TaprootWallet restored = TaprootWallet.fromJson(storedWallet);

        expect(
            restored.policyList, everyElement(isA<LegacyInheritancePolicy>()));
        expect(restored.getAddress(0), funded.getAddress(0));
      });
    });
  });
}
