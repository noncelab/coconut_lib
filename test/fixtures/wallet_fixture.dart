import 'package:coconut_lib/coconut_lib.dart';

import 'seed_fixture.dart';

enum TestWalletKind { standard, random }

abstract final class WalletFixture {
  static SingleSignatureVault p2wpkhVault(
      {TestWalletKind kind = TestWalletKind.standard, String passphrase = ''}) {
    if (kind == TestWalletKind.random) {
      return SingleSignatureVault.random();
    }
    return SingleSignatureVault.fromSeed(
        SeedFixture.common(passphrase: passphrase));
  }

  static TaprootVault p2trKeyPathVault(
      {TestWalletKind kind = TestWalletKind.standard, String passphrase = ''}) {
    final keyStore = kind == TestWalletKind.random
        ? KeyStore.random(AddressType.p2tr)
        : KeyStore.fromSeed(
            SeedFixture.common(passphrase: passphrase), AddressType.p2tr);
    return TaprootVault.fromKeyStoreList([keyStore], []);
  }

  static TaprootVault p2trMultikeyVault(
      {TestWalletKind kind = TestWalletKind.standard}) {
    final vaultA = p2wpkhVault(kind: kind, passphrase: 'A');
    final vaultB = p2wpkhVault(kind: kind, passphrase: 'B');
    return TaprootVault.fromKeyStoreList(
        [vaultA.keyStore, vaultB.keyStore], []);
  }

  static TaprootVault p2trPolicyVault() {
    final keyStoreA = KeyStore.fromSeed(
        SeedFixture.common(passphrase: 'A'), AddressType.p2tr);
    final keyStoreB = KeyStore.fromSeed(
        SeedFixture.common(passphrase: 'B'), AddressType.p2tr);
    final policies = ['A', 'B', 'C']
        .map((passphrase) => InheritancePolicy.fromDescriptorAndLocktime(
            beneficiaryVault(passphrase: passphrase).descriptor, 1767225600))
        .toList();
    return TaprootVault.fromKeyStoreList([keyStoreA, keyStoreB], policies);
  }

  static TaprootVault beneficiaryVault({String passphrase = ''}) {
    return TaprootVault.fromSeedList(
        [SeedFixture.common(passphrase: passphrase)], []);
  }

  static MultisignatureVault p2wshVault(
      {TestWalletKind kind = TestWalletKind.standard}) {
    final keyStores = ['A', 'B', 'C']
        .map((passphrase) => KeyStore.fromSeed(
            p2wpkhVault(kind: kind, passphrase: passphrase).keyStore.seed,
            AddressType.p2wsh))
        .toList();
    return MultisignatureVault.fromKeyStoreList(keyStores, 2);
  }
}
