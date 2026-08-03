part of '../../coconut_lib.dart';

// ignore_for_file: constant_identifier_names
enum MiniscriptOperation { pk, v, and_v, after, older }

enum MiniscriptType { boolean, verify, key, wrapped }

class Miniscript {
  final MiniscriptOperation op;
  final MiniscriptType type;
  final List<Miniscript> children;

  final String? pubkeyHex;
  final int? value;

  Miniscript._(
      {required this.op,
      required this.type,
      this.children = const [],
      this.pubkeyHex,
      this.value});

  factory Miniscript.pk(String pubkeyHex) {
    if (pubkeyHex.isEmpty) {
      throw FormatException('pk requires pubkey');
    }
    return Miniscript._(
      op: MiniscriptOperation.pk,
      type: MiniscriptType.key,
      children: const [],
      pubkeyHex: pubkeyHex,
    );
  }

  factory Miniscript.after(int value) {
    if (value <= 0) {
      throw FormatException('after requires a positive integer');
    }
    return Miniscript._(
      op: MiniscriptOperation.after,
      type: MiniscriptType.boolean,
      children: const [],
      value: value,
    );
  }

  factory Miniscript.older(int value) {
    if (value <= 0) {
      throw FormatException('older requires a positive integer');
    }
    return Miniscript._(
      op: MiniscriptOperation.older,
      type: MiniscriptType.boolean,
      children: const [],
      value: value,
    );
  }

  factory Miniscript.v(Miniscript child) {
    validate(MiniscriptOperation.v, [child]);
    return Miniscript._(
      op: MiniscriptOperation.v,
      type: MiniscriptType.verify,
      children: [child],
    );
  }

  factory Miniscript.andV(Miniscript left, Miniscript right) {
    validate(MiniscriptOperation.and_v, [left, right]);
    return Miniscript._(
      op: MiniscriptOperation.and_v,
      type: MiniscriptType.boolean,
      children: [left, right],
    );
  }

  factory Miniscript.forInheritance(int locktime, String pubkeyHex) {
    return Miniscript.andV(
        Miniscript.v(Miniscript.pk(pubkeyHex)), Miniscript.after(locktime));
  }

  factory Miniscript.forBackup(String pubkeyHex) {
    return Miniscript.pk(pubkeyHex);
  }

  String serializeForDescriptor() {
    switch (op) {
      case MiniscriptOperation.pk:
        final key = pubkeyHex;
        if (key == null || key.isEmpty) {
          throw StateError('pk node missing pubkeyHex');
        }
        return 'pk($key)';

      case MiniscriptOperation.v:
        if (children.length != 1) {
          throw StateError('v node must have exactly 1 child');
        }
        return 'v:${children[0].serializeForDescriptor()}';

      case MiniscriptOperation.and_v:
        if (children.length != 2) {
          throw StateError('and_v node must have exactly 2 children');
        }
        return 'and_v(${children[0].serializeForDescriptor()},${children[1].serializeForDescriptor()})';

      case MiniscriptOperation.after:
        final n = value;
        if (n == null) {
          throw StateError('after node missing value');
        }
        return 'after($n)';

      case MiniscriptOperation.older:
        final n = value;
        if (n == null) {
          throw StateError('older node missing value');
        }
        return 'older($n)';
    }
  }

  String serializeForScript() {
    final cmds = _compileToCommands();
    if (cmds.isEmpty) {
      return '';
    }
    return Script(cmds).rawSerialize();
  }

  List<dynamic> _compileToCommands() {
    switch (op) {
      case MiniscriptOperation.pk:
        final keyHex = pubkeyHex;
        if (keyHex == null || keyHex.isEmpty) {
          throw StateError('pk node missing pubkeyHex');
        }
        final keyBytes = Codec.decodeHex(keyHex);
        return <dynamic>[
          keyBytes,
          ScriptOperationCode.getHex('OP_CHECKSIG'),
        ];

      case MiniscriptOperation.v:
        if (children.length != 1) {
          throw StateError('v node must have exactly 1 child');
        }
        final child = children[0];
        if (child.op != MiniscriptOperation.pk) {
          throw UnsupportedError(
              'v only supports pk child for script compilation');
        }
        final keyHex = child.pubkeyHex;
        if (keyHex == null || keyHex.isEmpty) {
          throw StateError('v:pk missing pubkeyHex');
        }
        final keyBytes = Codec.decodeHex(keyHex);
        return <dynamic>[
          keyBytes,
          ScriptOperationCode.getHex('OP_CHECKSIGVERIFY'),
        ];

      case MiniscriptOperation.after:
        // Absolute locktime (CLTV).
        final n = value;
        if (n == null) {
          throw StateError('after node missing value');
        }
        final nBytes = Converter.intToLittleEndianBytes(n, 4);
        return <dynamic>[
          nBytes,
          ScriptOperationCode.getHex('OP_CHECKLOCKTIMEVERIFY'),
          ScriptOperationCode.getHex('OP_DROP'),
        ];

      case MiniscriptOperation.older:
        // Legacy compatibility: older was historically emitted for CLTV
        // inheritance policies, so keep interpreting it as absolute locktime.
        final n = value;
        if (n == null) {
          throw StateError('older node missing value');
        }
        final nBytes = Converter.intToLittleEndianBytes(n, 4);
        return <dynamic>[
          nBytes,
          ScriptOperationCode.getHex('OP_CHECKLOCKTIMEVERIFY'),
          ScriptOperationCode.getHex('OP_DROP'),
        ];

      case MiniscriptOperation.and_v:
        if (children.length != 2) {
          throw StateError('and_v node must have exactly 2 children');
        }
        final left = children[0];
        final right = children[1];

        // inheritance 패턴: and_v(v:pk, older|after) → timelock + DROP + pubkey + CHECKSIG
        if (left.op == MiniscriptOperation.v &&
            left.children.length == 1 &&
            left.children[0].op == MiniscriptOperation.pk &&
            (right.op == MiniscriptOperation.older ||
                right.op == MiniscriptOperation.after)) {
          final pkHex = left.children[0].pubkeyHex;
          if (pkHex == null || pkHex.isEmpty) {
            throw StateError('and_v left v:pk missing pubkeyHex');
          }
          final pkBytes = Codec.decodeHex(pkHex);
          if (pkBytes.length != 32) {
            throw FormatException(
                'taproot script path expects 32-byte x-only pubkey, got ${pkBytes.length} bytes');
          }
          final timelock = right.value;
          if (timelock == null) {
            throw StateError('and_v timelock node missing value');
          }
          final nBytes = Converter.intToLittleEndianBytes(timelock, 4);
          // Both the canonical after form and the legacy older form map to
          // the same CLTV tapscript to preserve existing wallet addresses.
          return <dynamic>[
            nBytes,
            ScriptOperationCode.getHex('OP_CHECKLOCKTIMEVERIFY'),
            ScriptOperationCode.getHex('OP_DROP'),
            pkBytes,
            ScriptOperationCode.getHex('OP_CHECKSIG'),
          ];
        }

        // 일반적인 and_v: 왼쪽(V) + 오른쪽(B) 스크립트 연결
        final out = <dynamic>[];
        out.addAll(left._compileToCommands());
        out.addAll(right._compileToCommands());
        return out;
    }
  }

  static void validate(MiniscriptOperation op, List<Miniscript> children) {
    switch (op) {
      case MiniscriptOperation.pk:
        if (children.isNotEmpty) {
          throw ArgumentError('pk must not have children');
        }

      case MiniscriptOperation.after:
        if (children.isNotEmpty) {
          throw ArgumentError('after must not have children');
        }
        return;

      case MiniscriptOperation.older:
        if (children.isNotEmpty) {
          throw ArgumentError('older must not have children');
        }
        return;

      case MiniscriptOperation.v:
        if (children.length != 1) {
          throw ArgumentError('v must have exactly 1 child');
        }

        final childType = children[0].type;

        if (childType != MiniscriptType.key) {
          throw ArgumentError(
            'v requires a child of type key, got $childType',
          );
        }
        return;

      case MiniscriptOperation.and_v:
        if (children.length != 2) {
          throw ArgumentError('and_v must have exactly 2 children');
        }

        final leftType = children[0].type;
        final rightType = children[1].type;

        if (leftType != MiniscriptType.verify) {
          throw ArgumentError(
            'and_v requires left child type verify, got $leftType',
          );
        }

        if (rightType != MiniscriptType.boolean) {
          throw ArgumentError(
            'and_v requires right child type boolean, got $rightType',
          );
        }
        return;
    }
  }
}
