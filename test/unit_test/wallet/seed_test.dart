@Tags(['unit'])

import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:test/test.dart';

import '../../mock_factory.dart';

void main() {
  group('Seed', () {
    late Seed seed;
    setUpAll(() {
      seed = MockFactory.createP2wpkhVault().keyStore.seed;
    });
    group('mnemonic', () {
      test('Get mnemonic from seed', () {
        expect(
            seed.mnemonic,
            utf8.encode(
                'machine crack daughter fish credit glare raven fever tunnel delay fish record'));
      });
    });
    group('passphrase', () {
      test('Get passphrase from seed', () {
        Seed targetSeed = Seed.fromEntropy(
            Codec.decodeHex('00000000000000000000000000000000'),
            passphrase: utf8.encode('passphrase'));
        expect(utf8.decode(targetSeed.mnemonic),
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
        expect(targetSeed.passphrase, utf8.encode('passphrase'));
      });
    });
    group('rootSeed', () {
      test('Get root seed from seed', () {
        expect(Codec.encodeHex(seed.rootSeed),
            'ae6a87214c18fb91824b34b4e027f46d51061fdece2b3042ca51bf9b80f5d075fddb304fd9857ff1e147f9d0147bdc3116572657d9e2232540e6fc962a11a254');
      });
    });
    group('Seed.random', () {
      test('Generate random seed', () {
        Seed seed1 = Seed.random(
            mnemonicLength: 24, passphrase: utf8.encode('passphrase'));
        Seed seed2 = Seed.random(
            mnemonicLength: 24, passphrase: utf8.encode('passphrase'));
        expect(seed1 != seed2, true);
      });

      test('Generate random seed with invalid mnemonic length exception', () {
        expect(
            () => Seed.random(
                mnemonicLength: 11, passphrase: utf8.encode('passphrase')),
            throwsException);
        expect(
            () => Seed.random(
                mnemonicLength: 25, passphrase: utf8.encode('passphrase')),
            throwsException);
        expect(
            () => Seed.random(
                mnemonicLength: 16, passphrase: utf8.encode('passphrase')),
            throwsException);
      });
    });
    group('Seed.fromEntropy', () {
      test('Generate seed from hex entropy', () {
        Seed targetSeed = Seed.fromEntropy(
            utf8.encode('000102030405060708090a0b0c0d0e0f'),
            passphrase: utf8.encode('passphrase'));
        expect(targetSeed.passphrase, utf8.encode('passphrase'));
      });
      test('Generate seed from hex entropy with invalid length exception', () {
        expect(
            () => Seed.fromEntropy(
                utf8.encode('000102030405060708090a0b0c0d0e0fa'),
                passphrase: utf8.encode('passphrase')),
            throwsException);
        expect(
            () => Seed.fromEntropy(
                utf8.encode(
                    '000102030405060708090a0b0c0d0e0fa000102030405060708090a0b0c0d0e0fa'),
                passphrase: utf8.encode('passphrase')),
            throwsException);
      });
    });

    group('Seed.fromMnemonic', () {
      test('Generate seed from mnemonic', () {
        Seed targetSeed = Seed.fromMnemonic(utf8.encode(
            'machine crack daughter fish credit glare raven fever tunnel delay fish record'));
        expect(seed.mnemonic, targetSeed.mnemonic);
      });

      test('Invalid mnemonic exception', () {
        expect(
            () => Seed.fromMnemonic(utf8.encode(
                'machine crack daughter fish credit glare raven fever tunnel delay fish abandon')),
            throwsException);
      });
    });
    group('operator ==', () {
      test('Check equal', () {
        Seed seed1 = Seed.fromMnemonic(utf8.encode(
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'));
        Seed seed2 = Seed.fromMnemonic(utf8.encode(
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'));
        expect(seed1 == seed2, true);
      });
    });
    group('hashCode', () {
      test('Get hash code', () {
        Seed targetSeed = Seed.fromEntropy(
            utf8.encode('000102030405060708090a0b0c0d0e0f'),
            passphrase: utf8.encode('passphrase'));
        expect(targetSeed.hashCode, 678682958);
      });
    });
    group('Seed.wipe', () {
      test('Clears mnemonic and default passphrase', () {
        Seed targetSeed = Seed.fromMnemonic(utf8.encode(
            'machine crack daughter fish credit glare raven fever tunnel delay fish record'));
        expect(targetSeed.mnemonic.isNotEmpty, true);
        expect(targetSeed.passphrase.isEmpty, true);

        targetSeed.wipe();

        expect(targetSeed.mnemonic, isEmpty);
        expect(targetSeed.passphrase, isEmpty);
      });

      test('Clears mnemonic and non-empty passphrase', () {
        Seed targetSeed = Seed.fromMnemonic(
            utf8.encode(
                'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
            passphrase: utf8.encode('secret-passphrase'));
        expect(targetSeed.passphrase, utf8.encode('secret-passphrase'));

        targetSeed.wipe();

        expect(targetSeed.mnemonic, isEmpty);
        expect(targetSeed.passphrase, isEmpty);
      });

      test('Second wipe keeps buffers empty', () {
        Seed targetSeed = Seed.fromEntropy(
            Codec.decodeHex('00000000000000000000000000000000'),
            passphrase: utf8.encode('passphrase'));
        expect(targetSeed.mnemonic.isNotEmpty, true);

        targetSeed.wipe();
        targetSeed.wipe();

        expect(targetSeed.mnemonic, isEmpty);
        expect(targetSeed.passphrase, isEmpty);
      });
    });
  });
}
