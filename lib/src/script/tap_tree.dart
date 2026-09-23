part of '../../coconut_lib.dart';

/// Taproot script tree (BIP-341 taptree, BIP-386 `TREE`).
///
/// The shape is part of the commitment: the same leaves grouped differently
/// hash to a different merkle root, and so to a different address. Keep it as
/// data rather than deriving it, so a tree read from a descriptor is the tree
/// that gets used.
///
/// `TREE := SCRIPT | { TREE , TREE }` — a lone leaf is written bare, braces
/// mark a branch.
///
/// {@category Scripts and Policies}
sealed class TapTree {
  const TapTree();

  /// Number of leaves under this node.
  int get leafCount;

  /// Leaves left to right; the order [getMerklePath] and policy indexes use.
  List<Policy> get leaves;

  /// Merkle root of this subtree for the given address.
  Uint8List getMerkleRoot(int addressIndex, {bool isChange = false});

  /// Sibling hashes from [leafIndex] up to this node, bottom first.
  ///
  /// That is the order a BIP-341 control block stores them in.
  List<Uint8List> getMerklePath(int leafIndex, int addressIndex,
      {bool isChange = false});

  /// BIP-386 `TREE` expression for this subtree.
  String toTreeExpression();

  /// Same shape, with every leaf policy passed through [convert].
  TapTree mapLeaves(Policy Function(Policy policy) convert);

  /// Build the tree this library commits to for a bare list of policies.
  ///
  /// Leaves are paired left to right and an odd leaf is promoted unchanged to
  /// the next level, so three leaves give `{{A,B},C}`. Every wallet built from
  /// a policy list alone depends on this exact shape for its address — see
  /// `test/unit_test/wallet/taproot_tree_shape_test.dart`.
  static TapTree? fromPolicies(List<Policy> policies) {
    if (policies.isEmpty) {
      return null;
    }

    return _foldCanonical<TapTree>(
        policies.map((policy) => TapLeaf(policy)).toList(),
        (left, right) => TapBranch(left, right));
  }

  /// [fromPolicies]'s grouping, applied to already-rendered leaf expressions.
  ///
  /// Lets a descriptor built from miniscript strings alone produce the same
  /// shape as one built from policies.
  static String? canonicalTreeExpression(List<String> leafExpressions) {
    if (leafExpressions.isEmpty) {
      return null;
    }
    return _foldCanonical<String>(
        List<String>.of(leafExpressions), (left, right) => '{$left,$right}');
  }

  /// Pair neighbours left to right, promoting an odd node, until one remains.
  static T _foldCanonical<T>(List<T> level, T Function(T, T) join) {
    while (level.length > 1) {
      final List<T> next = [];
      for (int i = 0; i < level.length; i += 2) {
        if (i + 1 == level.length) {
          next.add(level[i]);
          continue;
        }
        next.add(join(level[i], level[i + 1]));
      }
      level = next;
    }
    return level.first;
  }

  /// Leaf expressions of a `TREE`, left to right, without building policies.
  static List<String> flattenTreeExpression(String treeExpression) {
    final String expression = treeExpression.trim();
    if (expression.isEmpty) {
      throw const FormatException('Empty tap tree expression.');
    }
    if (!expression.startsWith('{')) {
      return [expression];
    }
    if (!expression.endsWith('}')) {
      throw FormatException('Unbalanced tap tree expression: $treeExpression');
    }

    final String inner = expression.substring(1, expression.length - 1);
    final int split = _topLevelCommaIndex(inner);
    if (split < 0) {
      throw FormatException(
          'A tap tree branch needs two children: $treeExpression');
    }
    return [
      ...flattenTreeExpression(inner.substring(0, split)),
      ...flattenTreeExpression(inner.substring(split + 1)),
    ];
  }

  /// Parse a BIP-386 `TREE` expression.
  ///
  /// Leaf scripts are read with [Policy.fromMiniscript].
  static TapTree parse(String treeExpression) {
    final String expression = treeExpression.trim();
    if (expression.isEmpty) {
      throw const FormatException('Empty tap tree expression.');
    }

    if (!expression.startsWith('{')) {
      return TapLeaf(Policy.fromMiniscript(expression));
    }
    if (!expression.endsWith('}')) {
      throw FormatException('Unbalanced tap tree expression: $treeExpression');
    }

    final String inner = expression.substring(1, expression.length - 1);
    final int split = _topLevelCommaIndex(inner);
    if (split < 0) {
      throw FormatException(
          'A tap tree branch needs two children: $treeExpression');
    }

    return TapBranch(
      TapTree.parse(inner.substring(0, split)),
      TapTree.parse(inner.substring(split + 1)),
    );
  }

  /// Index of the comma separating a branch's two children.
  static int _topLevelCommaIndex(String inner) {
    int braceDepth = 0;
    int parenDepth = 0;

    for (int i = 0; i < inner.length; i++) {
      final String char = inner[i];
      if (char == '{') {
        braceDepth++;
      } else if (char == '}') {
        braceDepth--;
      } else if (char == '(') {
        parenDepth++;
      } else if (char == ')') {
        parenDepth--;
      } else if (char == ',' && braceDepth == 0 && parenDepth == 0) {
        return i;
      }
    }

    return -1;
  }

  static Uint8List _tapBranchHash(Uint8List a, Uint8List b) {
    // BIP-341 sorts the pair, so which child is written first does not change
    // the branch hash — only the grouping does.
    final int compare = _lexicographicCompare(a, b);
    final Uint8List first = compare <= 0 ? a : b;
    final Uint8List second = compare <= 0 ? b : a;

    return Hash.taggedHash(
        'TapBranch', Uint8List.fromList([...first, ...second]));
  }

  static int _lexicographicCompare(Uint8List a, Uint8List b) {
    final int minLength = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < minLength; i++) {
      if (a[i] != b[i]) {
        return a[i] < b[i] ? -1 : 1;
      }
    }
    return a.length.compareTo(b.length);
  }
}

/// A single tapscript leaf.
///
/// {@category Scripts and Policies}
class TapLeaf extends TapTree {
  final Policy policy;

  const TapLeaf(this.policy);

  @override
  int get leafCount => 1;

  @override
  List<Policy> get leaves => List.unmodifiable([policy]);

  @override
  Uint8List getMerkleRoot(int addressIndex, {bool isChange = false}) {
    return policy.getTapleafHash(addressIndex, isChange: isChange);
  }

  @override
  List<Uint8List> getMerklePath(int leafIndex, int addressIndex,
      {bool isChange = false}) {
    if (leafIndex != 0) {
      throw RangeError.range(leafIndex, 0, 0, 'leafIndex');
    }
    return const [];
  }

  @override
  String toTreeExpression() => policy.toMiniscript();

  @override
  TapTree mapLeaves(Policy Function(Policy policy) convert) =>
      TapLeaf(convert(policy));
}

/// A branch joining two subtrees.
///
/// {@category Scripts and Policies}
class TapBranch extends TapTree {
  final TapTree left;
  final TapTree right;

  const TapBranch(this.left, this.right);

  @override
  int get leafCount => left.leafCount + right.leafCount;

  @override
  List<Policy> get leaves =>
      List.unmodifiable([...left.leaves, ...right.leaves]);

  @override
  Uint8List getMerkleRoot(int addressIndex, {bool isChange = false}) {
    return TapTree._tapBranchHash(
      left.getMerkleRoot(addressIndex, isChange: isChange),
      right.getMerkleRoot(addressIndex, isChange: isChange),
    );
  }

  @override
  List<Uint8List> getMerklePath(int leafIndex, int addressIndex,
      {bool isChange = false}) {
    if (leafIndex < 0 || leafIndex >= leafCount) {
      throw RangeError.range(leafIndex, 0, leafCount - 1, 'leafIndex');
    }

    if (leafIndex < left.leafCount) {
      return [
        ...left.getMerklePath(leafIndex, addressIndex, isChange: isChange),
        right.getMerkleRoot(addressIndex, isChange: isChange),
      ];
    }
    return [
      ...right.getMerklePath(leafIndex - left.leafCount, addressIndex,
          isChange: isChange),
      left.getMerkleRoot(addressIndex, isChange: isChange),
    ];
  }

  @override
  String toTreeExpression() =>
      '{${left.toTreeExpression()},${right.toTreeExpression()}}';

  @override
  TapTree mapLeaves(Policy Function(Policy policy) convert) =>
      TapBranch(left.mapLeaves(convert), right.mapLeaves(convert));
}
