import 'dart:convert';
import 'dart:math';

import 'package:coconut_lib/coconut_lib.dart';

enum TestWalletType {
  /// Regtest, 트랜잭션과 UTXO가 수십개 포함된 싱글 시그 지갑
  forNormal,

  /// 랜덤 생성된 싱글 시그 지갑 (트랜잭션, UTXO 없음)
  random
}

abstract class MockFactory {
  static String reveiveAddress = 'bcrt1qxdyjf6h5d6qxap4n2dap97q4j5ps6ua8jkxz0z';
  static Seed getCommonSeed({String passphrase = ''}) {
    return Seed.fromMnemonic(
        utf8.encode(
            'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
        passphrase: utf8.encode(passphrase));
  }

  static KeyStore getCommonKeyStore(AddressType addressType) {
    return KeyStore.fromSeed(getCommonSeed(), addressType);
  }

  static Utxo getCommonUtxo(AddressType addressType) {
    String derivationPath = WalletUtility.getDerivationPath(addressType, 0);
    return Utxo(
        '0000000000000000000000000000000000000000000000000000000000000000',
        0,
        100000,
        "$derivationPath/0/0");
  }

  static SingleSignatureVault createP2wpkhVault(
      {TestWalletType testWalletType = TestWalletType.forNormal,
      String passphrase = ''}) {
    SingleSignatureVault? vault;
    if (testWalletType == TestWalletType.forNormal) {
      vault = SingleSignatureVault.fromMnemonic(
          utf8.encode(
              'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
          passphrase: utf8.encode(passphrase));
    } else if (testWalletType == TestWalletType.random) {
      vault = SingleSignatureVault.random();
    }
    return vault!;
  }

  static TaprootVault createP2trKeyPathSpendingVault(
      {TestWalletType testWalletType = TestWalletType.forNormal,
      String passphrase = ''}) {
    TaprootVault? vault;
    if (testWalletType == TestWalletType.forNormal) {
      vault = TaprootVault.fromKeyStoreList([
        KeyStore.fromSeed(
            Seed.fromMnemonic(utf8.encode(
                'machine crack daughter fish credit glare raven fever tunnel delay fish record')),
            AddressType.p2tr)
      ], []);
    } else if (testWalletType == TestWalletType.random) {
      vault = TaprootVault.fromKeyStoreList(
          [KeyStore.random(AddressType.p2tr)], []);
    }
    return vault!;
  }

  static TaprootVault createP2trVaultOnlyKeys(
      {TestWalletType testWalletType = TestWalletType.forNormal,
      String passphrase = ''}) {
    SingleSignatureVault vault1 =
        createP2wpkhVault(testWalletType: testWalletType, passphrase: 'A');
    SingleSignatureVault vault2 =
        createP2wpkhVault(testWalletType: testWalletType, passphrase: 'B');
    return TaprootVault.fromKeyStoreList(
        [vault1.keyStore, vault2.keyStore], []);
  }

  static TaprootVault createP2trVaultWithPolicies(
      {TestWalletType testWalletType = TestWalletType.forNormal,
      String passphrase = ''}) {
    KeyStore keyStore1 = KeyStore.fromSeed(
        Seed.fromMnemonic(
            utf8.encode(
                'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
            passphrase: utf8.encode('A')),
        AddressType.p2tr);
    KeyStore keyStore2 = KeyStore.fromSeed(
        Seed.fromMnemonic(
            utf8.encode(
                'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
            passphrase: utf8.encode('B')),
        AddressType.p2tr);
    Policy policy1 = InheritancePolicy.fromDescriptorAndLocktime(
        createBeneficiaryVault(passphrase: 'A').descriptor, 1767225600);
    Policy policy2 = InheritancePolicy.fromDescriptorAndLocktime(
        createBeneficiaryVault(passphrase: 'B').descriptor, 1767225600);
    Policy policy3 = InheritancePolicy.fromDescriptorAndLocktime(
        createBeneficiaryVault(passphrase: 'C').descriptor, 1767225600);
    return TaprootVault.fromKeyStoreList(
        [keyStore1, keyStore2], [policy1, policy2, policy3]);
  }

  static TaprootVault createBeneficiaryVault(
      {TestWalletType testWalletType = TestWalletType.forNormal,
      String passphrase = ''}) {
    TaprootVault? vault;
    if (testWalletType == TestWalletType.forNormal) {
      vault = TaprootVault.fromSeedList([
        Seed.fromMnemonic(
            utf8.encode(
                'machine crack daughter fish credit glare raven fever tunnel delay fish record'),
            passphrase: utf8.encode(passphrase))
      ], []);
    }
    return vault!;
  }

  static MultisignatureVault createP2wshVault(
      {TestWalletType testWalletType = TestWalletType.forNormal}) {
    final vault1 =
        createP2wpkhVault(testWalletType: testWalletType, passphrase: 'A');
    final vault2 =
        createP2wpkhVault(testWalletType: testWalletType, passphrase: 'B');
    final vault3 =
        createP2wpkhVault(testWalletType: testWalletType, passphrase: 'C');

    KeyStore keyStore1 =
        KeyStore.fromSeed(vault1.keyStore.seed, AddressType.p2wsh);
    KeyStore keyStore2 =
        KeyStore.fromSeed(vault2.keyStore.seed, AddressType.p2wsh);
    KeyStore keyStore3 =
        KeyStore.fromSeed(vault3.keyStore.seed, AddressType.p2wsh);

    MultisignatureVault vault = MultisignatureVault.fromKeyStoreList(
        [keyStore1, keyStore2, keyStore3], 2);

    return vault;
  }

  static Utxo createUtxo(
      {int amount = 100000,
      String derivationPath = "m/84'/1'/0'/0/0",
      String entropy = ''}) {
    if (entropy.isEmpty) {
      entropy = "FakeTransactionHash${Random().nextInt(100000)}";
    }
    String fakeTransactionHash = Codec.encodeHex(Hash.sha256(entropy));
    return Utxo(fakeTransactionHash, 0, amount, derivationPath);
  }

  static List<Utxo> createUtxoList(
      {int count = 10, String derivationPath = "m/84'/1'/0'/0/0"}) {
    List<Utxo> utxos = [];
    for (int i = 0; i < count; i++) {
      utxos.add(createUtxo(
          entropy: "utxo #${i.toString()}", derivationPath: derivationPath));
    }
    return utxos;
  }

  static List<Utxo> createTaprootUtxoList(
      {int count = 10, String derivationPath = "m/86'/1'/0'/0/0"}) {
    List<Utxo> utxos = [];
    for (int i = 0; i < count; i++) {
      utxos.add(createUtxo(
          entropy: "utxo #${i.toString()}", derivationPath: derivationPath));
    }
    return utxos;
  }

  static Psbt createP2wpkhUnsignedPsbt() {
    SingleSignatureVault vault = createP2wpkhVault();
    Transaction tx = Transaction.forSinglePayment(
        createUtxoList(count: 1, derivationPath: '${vault.derivationPath}/0/0'),
        vault.getAddress(1),
        '${vault.derivationPath}/1/1',
        15000,
        3,
        vault);
    return Psbt.fromTransaction(tx, vault);
  }

  static Psbt createP2wshUnsignedPsbt() {
    MultisignatureVault vault = createP2wshVault();
    Transaction tx = Transaction.forSinglePayment(
        createUtxoList(count: 2, derivationPath: '${vault.derivationPath}/0/0'),
        vault.getAddress(1),
        '${vault.derivationPath}/1/1',
        15000,
        3,
        vault);
    return Psbt.fromTransaction(tx, vault);
  }

  static Psbt createP2wshSignedPsbt() {
    MultisignatureVault vault = createP2wshVault();
    Transaction tx = Transaction.forSinglePayment(
        createUtxoList(count: 2, derivationPath: '${vault.derivationPath}/0/0'),
        vault.getAddress(1),
        '${vault.derivationPath}/1/1',
        15000,
        3,
        vault);
    Psbt unsignedPsbt = Psbt.fromTransaction(tx, vault);

    return Psbt.parse(vault.addSignatureToPsbt(unsignedPsbt.serialize()));
  }

  static Psbt createP2wpkhSignedPsbt() {
    SingleSignatureVault vault = createP2wpkhVault();
    Transaction tx = Transaction.forSinglePayment(
        createUtxoList(count: 1, derivationPath: '${vault.derivationPath}/0/0'),
        vault.getAddress(1),
        '${vault.derivationPath}/1/1',
        15000,
        3,
        vault);
    Psbt unsignedPsbt = Psbt.fromTransaction(tx, vault);

    return Psbt.parse(vault.addSignatureToPsbt(unsignedPsbt.serialize()));
  }

  static Psbt createP2trKeyPathSpendingUnsignedPsbt() {
    TaprootVault vault = createP2trKeyPathSpendingVault();
    Transaction tx = Transaction.forSinglePayment(
        createTaprootUtxoList(
            count: 1, derivationPath: '${vault.derivationPath}/0/0'),
        vault.getAddress(1),
        '${vault.derivationPath}/1/1',
        15000,
        3,
        vault);
    return Psbt.fromTransaction(tx, vault);
  }

  static Psbt createP2trKeyPathSpendingSignedPsbt() {
    TaprootVault vault = createP2trKeyPathSpendingVault();
    Transaction tx = Transaction.forSinglePayment(
        createTaprootUtxoList(
            count: 1, derivationPath: '${vault.derivationPath}/0/0'),
        vault.getAddress(1),
        '${vault.derivationPath}/1/1',
        15000,
        3,
        vault);
    Psbt unsignedPsbt = Psbt.fromTransaction(tx, vault);

    return Psbt.parse(vault.addSignatureToPsbt(unsignedPsbt.serialize()));
  }

  Transaction getMockTransaction(String scriptPubKey, int amount,
      {bool isCoinbase = false, AddressType? addressType}) {
    addressType ??= AddressType.p2wpkh;

    late String address;
    if (addressType == AddressType.p2wpkh) {
      address = addressType.getAddress(scriptPubKey);
    } else if (addressType == AddressType.p2wsh) {
      address = addressType.getMultisignatureAddress([scriptPubKey], 1);
    }

    List<TransactionInput> inputs = [];

    if (isCoinbase) {
      inputs.add(TransactionInput.forPayment(
          '0000000000000000000000000000000000000000000000000000000000000000',
          4294967295));
    } else {
      inputs.add(TransactionInput.forPayment(
          Codec.encodeHex(Hash.sha256('$scriptPubKey$amount')), 0));
    }

    List<TransactionOutput> outputs = [
      TransactionOutput.forPayment(amount, address),
    ];

    return Transaction.withInputsAndOutputs(inputs, outputs, addressType);
  }
}
