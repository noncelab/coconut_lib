## Unreleased

### Breaking

- Descriptor output now follows the specs. Addresses, keys and signatures are
  unchanged; only the descriptor string and its checksum differ, so stored
  descriptors and any `sha256(descriptor)` identifier computed from them must be
  refreshed.
  - Inheritance policies are written as `and_v(v:after(N),pk(K))`, matching the
    script they compile to. The previous `and_v(v:pk(K),after(N))` described a
    different script (`<K> CHECKSIGVERIFY <N> CLTV`), so a wallet deriving from
    the descriptor reached a different address than this library did.
  - MuSig2 key expressions are written as `musig(KEY,...)` per BIP-390; the
    non-standard `sorted()` wrapper is gone. Sorting is unchanged — KeyAgg
    already sorts, as the spec mandates.
  - Taproot script trees are written as a BIP-386 `TREE`: a lone leaf bare,
    every branch in braces, e.g. `tr(KEY,{A,{B,C}})`. The previous
    `tr(KEY,{A},{B},{C})` was not valid syntax and, worse, did not say how the
    leaves were grouped — so a wallet reading it derived a different address
    from three leaves onward.
  - All previous spellings are still parsed, so descriptors and policy JSON
    written by earlier versions keep loading.
- `TransactionInput.setTaprootScriptPathSpendingSignature` takes a
  `List<String>` of signature stack items instead of a single signature.
- `OP_NUMEQUAL` was mapped to `0x87` (`OP_EQUAL`); it is now `0x9c`, and
  `OP_EQUAL` was added.

### Added

- `TapTree` (`TapLeaf`, `TapBranch`) holds a Taproot script tree with its
  shape, and `TaprootVault.fromTapTree` / `TaprootWallet.fromTapTree` build a
  wallet from one. Grouping decides the merkle root, so `{A,{B,C}}` and
  `{{A,B},C}` are different addresses; a tree that arrives with a shape — from
  a descriptor, JSON, or a caller — keeps it, and its leaves are not re-sorted.
  A bare policy list still gets the previous default grouping, so existing
  wallets keep their addresses.
- `TaprootWalletBase.tapTree` and `getMerklePathLength`; fee estimation now
  measures the spent leaf's real depth instead of guessing from the leaf count,
  and `estimateVirtualByte` takes `merklePathLength`.
- `SingleSignaturePolicy` and `MultisignaturePolicy` Taproot script-path
  policies, including k-of-n `multi_a` leaves through PSBT signing,
  finalization and witness verification.
- `Policy.keyStoreList`, `Policy.requiredSignature` and `Policy.bindKeyStore`,
  so signer enumeration no longer type-switches on the policy class.
- Optional `auxRand` on the MuSig2 nonce path (`TaprootVault.addPublicNonce`,
  `KeyStore.addPublicNonceToPsbt`, `addPublicNonceToPsbtInput`,
  `getPublicNonce`, `getSecretNonce`) for deterministic tests. Reusing a value
  across signatures over different messages reveals the private key.

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

