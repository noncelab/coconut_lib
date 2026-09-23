@Tags(['unit'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

void main() {
  group('TapTree', () {
    const String mnemonic =
        'machine crack daughter fish credit glare raven fever tunnel delay fish record';

    KeyStore keyStore(String passphrase) => KeyStore.fromSeed(
        Seed.fromMnemonic(utf8.encode(mnemonic),
            passphrase: utf8.encode(passphrase)),
        AddressType.p2tr);

    late Policy a;
    late Policy b;
    late Policy c;

    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
      a = InheritancePolicy(keyStore('leaf A'), 1767225600);
      b = InheritancePolicy(keyStore('leaf B'), 1767225601);
      c = InheritancePolicy(keyStore('leaf C'), 1767225602);
    });

    TapTree rightLeaning() =>
        TapBranch(TapLeaf(a), TapBranch(TapLeaf(b), TapLeaf(c)));
    TapTree leftLeaning() =>
        TapBranch(TapBranch(TapLeaf(a), TapLeaf(b)), TapLeaf(c));

    /// BIP-341 TapBranch, computed here rather than through the tree.
    Uint8List branch(Uint8List x, Uint8List y) {
      int compare = 0;
      for (int i = 0; i < 32; i++) {
        if (x[i] != y[i]) {
          compare = x[i] < y[i] ? -1 : 1;
          break;
        }
      }
      final Uint8List first = compare <= 0 ? x : y;
      final Uint8List second = compare <= 0 ? y : x;
      return Hash.taggedHash(
          'TapBranch', Uint8List.fromList([...first, ...second]));
    }

    group('getMerkleRoot', () {
      test('matches the BIP-341 hash of the written shape', () {
        final Uint8List expected = branch(a.getTapleafHash(0),
            branch(b.getTapleafHash(0), c.getTapleafHash(0)));
        expect(rightLeaning().getMerkleRoot(0), expected);
      });

      test('grouping changes the root', () {
        expect(rightLeaning().getMerkleRoot(0),
            isNot(leftLeaning().getMerkleRoot(0)));
      });

      test('a single leaf roots at its own tapleaf hash', () {
        expect(TapLeaf(a).getMerkleRoot(0), a.getTapleafHash(0));
      });
    });

    group('getMerklePath', () {
      test('collects siblings bottom up', () {
        final TapTree tree = rightLeaning();
        // A sits one level down; B and C sit two.
        expect(tree.getMerklePath(0, 0), [
          branch(b.getTapleafHash(0), c.getTapleafHash(0)),
        ]);
        expect(tree.getMerklePath(1, 0), [
          c.getTapleafHash(0),
          a.getTapleafHash(0),
        ]);
        expect(tree.getMerklePath(2, 0), [
          b.getTapleafHash(0),
          a.getTapleafHash(0),
        ]);
      });

      test('rejects a leaf index outside the tree', () {
        expect(() => rightLeaning().getMerklePath(3, 0), throwsRangeError);
      });
    });

    group('toTreeExpression', () {
      test('writes braces only for branches', () {
        expect(TapLeaf(a).toTreeExpression(), a.toMiniscript());
        expect(rightLeaning().toTreeExpression(),
            '{${a.toMiniscript()},{${b.toMiniscript()},${c.toMiniscript()}}}');
      });
    });

    group('parse', () {
      test('round-trips a nested expression', () {
        final TapTree original = rightLeaning();
        final TapTree parsed = TapTree.parse(original.toTreeExpression());
        expect(parsed.toTreeExpression(), original.toTreeExpression());
        expect(parsed.getMerkleRoot(0), original.getMerkleRoot(0));
        expect(parsed.leafCount, 3);
      });

      test('keeps the shape it was given', () {
        expect(TapTree.parse(leftLeaning().toTreeExpression()).getMerkleRoot(0),
            leftLeaning().getMerkleRoot(0));
        expect(TapTree.parse(leftLeaning().toTreeExpression()).getMerkleRoot(0),
            isNot(rightLeaning().getMerkleRoot(0)));
      });

      test('reads a bare leaf', () {
        final TapTree parsed = TapTree.parse(a.toMiniscript());
        expect(parsed, isA<TapLeaf>());
        expect(parsed.leafCount, 1);
      });

      test('rejects a branch with one child', () {
        expect(() => TapTree.parse('{${a.toMiniscript()}}'),
            throwsFormatException);
      });

      test('rejects an unbalanced expression', () {
        expect(() => TapTree.parse('{${a.toMiniscript()},'),
            throwsFormatException);
      });
    });

    group('fromPolicies', () {
      test('pairs neighbours and promotes the odd leaf', () {
        expect(TapTree.fromPolicies([a, b, c])!.toTreeExpression(),
            leftLeaning().toTreeExpression());
      });

      test('returns null without policies', () {
        expect(TapTree.fromPolicies([]), isNull);
      });

      test('a lone policy becomes a bare leaf', () {
        expect(TapTree.fromPolicies([a])!.toTreeExpression(), a.toMiniscript());
      });
    });

    group('leaves', () {
      test('are ordered left to right', () {
        expect(rightLeaning().leaves.map((policy) => policy.toMiniscript()),
            [a.toMiniscript(), b.toMiniscript(), c.toMiniscript()]);
      });
    });
  });
}
