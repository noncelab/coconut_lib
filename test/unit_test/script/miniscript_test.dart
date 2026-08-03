@Tags(['unit'])
import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../mock_factory.dart';

void main() {
  group('Miniscript', () {
    late TaprootVault beneficiaryVault;

    setUp(() {
      NetworkType.setNetworkType(NetworkType.regtest);
      beneficiaryVault = MockFactory.createBeneficiaryVault(passphrase: 'C');
    });

    group('pk', () {
      test('rejects empty pubkey hex', () {
        expect(() => Miniscript.pk(''), throwsFormatException);
      });
    });

    group('after', () {
      test('rejects non-positive values', () {
        expect(() => Miniscript.after(0), throwsFormatException);
      });
    });

    group('older', () {
      test('rejects non-positive values', () {
        expect(() => Miniscript.older(-1), throwsFormatException);
      });
    });

    group('validate', () {
      test('rejects pk with children', () {
        expect(
            () => Miniscript.validate(
                MiniscriptOperation.pk, [Miniscript.pk('11')]),
            throwsArgumentError);
      });

      test('rejects after/older when children are passed', () {
        expect(
            () => Miniscript.validate(
                MiniscriptOperation.after, [Miniscript.pk('ab')]),
            throwsArgumentError);
        expect(
            () => Miniscript.validate(
                MiniscriptOperation.older, [Miniscript.pk('ab')]),
            throwsArgumentError);
      });

      test('rejects and_v when right child is not boolean', () {
        expect(
            () => Miniscript.validate(MiniscriptOperation.and_v,
                [Miniscript.v(Miniscript.pk('ab')), Miniscript.pk('cd')]),
            throwsArgumentError);
      });
    });

    group('v', () {
      test('rejects child without a key', () {
        expect(() => Miniscript.v(Miniscript.older(10)), throwsArgumentError);
      });
    });

    group('andV', () {
      test('rejects children with invalid types', () {
        expect(() => Miniscript.andV(Miniscript.pk('ab'), Miniscript.older(10)),
            throwsArgumentError);
      });
    });

    group('serializeForDescriptor', () {
      test('serializes inheritance-like tree', () {
        final String pkHex = Codec.encodeHex(beneficiaryVault.keyStoreList[0]
            .getPublicKeyBytes(0, isXOnly: true));
        final Miniscript tree = Miniscript.forInheritance(1767225600, pkHex);
        expect(tree.serializeForDescriptor(),
            'and_v(v:pk($pkHex),older(1767225600))');
      });

      test('serializes single after/older nodes', () {
        expect(Miniscript.after(42).serializeForDescriptor(), 'after(42)');
        expect(Miniscript.older(99).serializeForDescriptor(), 'older(99)');
      });
    });

    group('serializeForScript', () {
      test('pk compiles to <pubkey> OP_CHECKSIG', () {
        final String pkHex = Codec.encodeHex(beneficiaryVault.keyStoreList[0]
            .getPublicKeyBytes(0, isXOnly: true));
        final String fromMiniscript = Miniscript.pk(pkHex).serializeForScript();
        final String expected = Script(<dynamic>[
          Codec.decodeHex(pkHex),
          ScriptOperationCode.getHex('OP_CHECKSIG'),
        ]).rawSerialize();
        expect(fromMiniscript.toLowerCase(), expected.toLowerCase());
      });

      test('v:pk compiles to <pubkey> OP_CHECKSIGVERIFY', () {
        final String pkHex = Codec.encodeHex(beneficiaryVault.keyStoreList[0]
            .getPublicKeyBytes(1, isXOnly: true));
        final String fromMiniscript =
            Miniscript.v(Miniscript.pk(pkHex)).serializeForScript();
        final String expected = Script(<dynamic>[
          Codec.decodeHex(pkHex),
          ScriptOperationCode.getHex('OP_CHECKSIGVERIFY'),
        ]).rawSerialize();
        expect(fromMiniscript.toLowerCase(), expected.toLowerCase());
      });

      test('matches InheritancePolicy tapscript bytes for same keys', () {
        const int locktime = 1767225600;
        final KeyStore ks = beneficiaryVault.keyStoreList[0];
        final InheritancePolicy policy = InheritancePolicy(ks, locktime);

        final String pkHex =
            Codec.encodeHex(ks.getPublicKeyBytes(0, isXOnly: true));
        final Miniscript tree = Miniscript.forInheritance(locktime, pkHex);

        expect(tree.serializeForScript().toLowerCase(),
            policy.toScript(0).rawSerialize().toLowerCase());
      });

      test('after compiles to CSV drop pattern', () {
        final String fromMiniscript = Miniscript.after(42).serializeForScript();
        final String expected = Script(<dynamic>[
          Converter.intToLittleEndianBytes(42, 4),
          ScriptOperationCode.getHex('OP_CHECKSEQUENCEVERIFY'),
          ScriptOperationCode.getHex('OP_DROP'),
        ]).rawSerialize();
        expect(fromMiniscript.toLowerCase(), expected.toLowerCase());
      });

      test('older compiles to CLTV drop pattern', () {
        final String fromMiniscript = Miniscript.older(9).serializeForScript();
        final String expected = Script(<dynamic>[
          Converter.intToLittleEndianBytes(9, 4),
          ScriptOperationCode.getHex('OP_CHECKLOCKTIMEVERIFY'),
          ScriptOperationCode.getHex('OP_DROP'),
        ]).rawSerialize();
        expect(fromMiniscript.toLowerCase(), expected.toLowerCase());
      });

      test('and_v(v:pk, after) compiles to CSV + pubkey + checksig', () {
        final String pkHex = Codec.encodeHex(beneficiaryVault.keyStoreList[0]
            .getPublicKeyBytes(0, isXOnly: true));
        final String fromMiniscript = Miniscript.andV(
                Miniscript.v(Miniscript.pk(pkHex)), Miniscript.after(7))
            .serializeForScript();
        final String expected = Script(<dynamic>[
          Converter.intToLittleEndianBytes(7, 4),
          ScriptOperationCode.getHex('OP_CHECKSEQUENCEVERIFY'),
          ScriptOperationCode.getHex('OP_DROP'),
          Codec.decodeHex(pkHex),
          ScriptOperationCode.getHex('OP_CHECKSIG'),
        ]).rawSerialize();
        expect(fromMiniscript.toLowerCase(), expected.toLowerCase());
      });

      test('and_v falls back to concatenating left/right scripts', () {
        final String pkHex = Codec.encodeHex(beneficiaryVault.keyStoreList[0]
            .getPublicKeyBytes(0, isXOnly: true));
        final Miniscript nested = Miniscript.andV(
            Miniscript.v(Miniscript.pk(pkHex)), Miniscript.older(7));
        final String fromMiniscript =
            Miniscript.andV(Miniscript.v(Miniscript.pk(pkHex)), nested)
                .serializeForScript();
        final String expected = Script(<dynamic>[
          Codec.decodeHex(pkHex),
          ScriptOperationCode.getHex('OP_CHECKSIGVERIFY'),
          Converter.intToLittleEndianBytes(7, 4),
          ScriptOperationCode.getHex('OP_CHECKLOCKTIMEVERIFY'),
          ScriptOperationCode.getHex('OP_DROP'),
          Codec.decodeHex(pkHex),
          ScriptOperationCode.getHex('OP_CHECKSIG'),
        ]).rawSerialize();
        expect(fromMiniscript.toLowerCase(), expected.toLowerCase());
      });

      test('inheritance compile throws when pubkey is not x-only 32 bytes', () {
        final String nonXOnly33 =
            '02' + ('11' * 32); // compressed key-like 33-byte input
        expect(
            () => Miniscript.andV(Miniscript.v(Miniscript.pk(nonXOnly33)),
                    Miniscript.after(5))
                .serializeForScript(),
            throwsFormatException);
      });
    });

    group('forBackup', () {
      test('returns pk-only miniscript', () {
        final String pkHex = Codec.encodeHex(beneficiaryVault.keyStoreList[0]
            .getPublicKeyBytes(1, isXOnly: true));
        expect(
            Miniscript.forBackup(pkHex).serializeForDescriptor(), 'pk($pkHex)');
      });
    });
  });
}
