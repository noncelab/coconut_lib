import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';

abstract final class SeedFixture {
  static const mnemonic =
      'machine crack daughter fish credit glare raven fever tunnel delay fish record';

  static Seed common({String passphrase = ''}) {
    return Seed.fromMnemonic(utf8.encode(mnemonic),
        passphrase: utf8.encode(passphrase));
  }
}
