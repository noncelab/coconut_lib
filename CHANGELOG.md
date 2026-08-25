## 1.1.1

- Enhance security
- Update license

## 1.1.0

- Support P2TR and taproot policy

## 1.0.4

- Support HWW for multisig signing

## 1.0.3

- Fix key store bug

## 1.0.2

- Improve security

## 1.0.0

- Fix finger printer bug

## 1.0.0

- Add parse coinbase transaction
- Add sweep to multiple address

## 0.10.5

- Add estimate fee with number of input/output

## 0.10.4

- Support brain wallet

## 0.10.3

- Fix transaction parser
- Fix script parser

## 0.10.2

- Change method name canSignToPsbt -&gt; hasPublicKeyInPsbt
- Add PlantUML class diagram

## 0.10.1

- Added support for hardware wallets (Keystone, SeedSigner)
- Implemented MuSig2 spending functionality

## 0.9.2

- Fix DER encoding bug

## 0.9.1

- Split Ecc.signEcdsa and Ecc.signSchnorr into separate methods
- Split HdWallet.sign into HdWallet.signEcdsa and HdWallet.signSchnorr
- Split Ecc.verify into Ecc.verifyEcdsa and Ecc.verifySchnorr
- Split HdWallet.verify into HdWallet.verifyEcdsa and HdWallet.verifySchnorr
- Removed KeyStore.signWithDerivationPath(String message, String derivationPath, {bool isSchnorr = false})
- Removed KeyStore.sign(String message, int addressIndex, {bool isChange = false, isSchnorr = false})

## 0.9.0

- Remove electrum connection
- Taproot key-path spending support
- Batch transaction support
- UTXO selection support

## 0.8.2

- UTXO selection support.
- Fix network bug.

## 0.8.1

- Fix PSBT bug.

## 0.8.0

- Multisig wallet support.

## 0.7.0

- Replaced Objectbox with a File-based database.

## 0.6.2

- Mnemonic validation added.

## 0.6.1

- Fix validate multisig address.
- Fixed an address return error that occurred before the initial network connection.
- pub.dev guidelines compliance.

## 0.6.0+1

- pub.dev guidelines compliance.

## 0.6.0

- Initial release.

