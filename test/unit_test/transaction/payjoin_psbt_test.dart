@Tags(['unit'])
library;

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('payjoin fixtures', () {
    test('foreign inputs are finalized and carry no derivations', () {
      final Psbt psbt = PayjoinFixture.senderProposal();

      expect(psbt.inputs[1].isFinalized, isTrue);
      expect(psbt.inputs[1].witnessUtxo, isNotNull);
      expect(psbt.inputs[1].bip32Derivation, isNull);
      expect(psbt.inputs[0].isFinalized, isFalse);
      expect(psbt.inputs[2].isFinalized, isFalse);
    });

    test('final_script_sig marks an input finalized', () {
      final Map<String, dynamic> keyMap =
          PayjoinFixture.senderProposal().toKeyMap();
      keyMap['inputs'][1]
        ..remove('08')
        ..['07'] = '160014${'ab' * 20}';
      final Psbt psbt = Psbt.parse(Psbt.fromMap(keyMap).serialize());

      expect(psbt.inputs[1].finalScriptSig, '160014${'ab' * 20}');
      expect(psbt.inputs[1].isFinalized, isTrue);
    });
  });
}
