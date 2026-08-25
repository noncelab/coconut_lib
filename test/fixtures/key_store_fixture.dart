import 'package:coconut_lib/coconut_lib.dart';

import 'seed_fixture.dart';

abstract final class KeyStoreFixture {
  static KeyStore common(AddressType addressType, {String passphrase = ''}) {
    return KeyStore.fromSeed(
        SeedFixture.common(passphrase: passphrase), addressType);
  }
}
