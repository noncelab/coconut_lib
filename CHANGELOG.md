## 1.1.5

- Stop comparing the PSBT's coconut descriptor identifier with the multisig
  vault's descriptor in `Psbt.matchesVault`. A P2WSH descriptor lists the keys
  in the order they were given, so the same vault can serialize differently and
  fail the match; ownership rests on the global xpubs (when present) and the
  per-input BIP32 derivation checks

## 1.1.4

- Build the InheritancePolicy leaf as `<N> CLTV VERIFY <K> CHECKSIG`, which is
  what miniscript `and_v(v:after(N),pk(K))` compiles to (BIP-379); earlier
  versions built `<N> CLTV DROP <K> CHECKSIG`. The two leaves behave alike for
  N >= 1 but commit to different leaf hashes, so new inheritance vaults derive
  different addresses than they did before
- Push the InheritancePolicy locktime as a minimal script number, as a
  miniscript compiler does: `OP_1`..`OP_16` for 1..16, otherwise the fewest
  bytes. It was always four bytes, which gave another leaf and address for any
  locktime below 2^23, such as a block height; Unix timestamps are unchanged
- Reject InheritancePolicy locktime 0 and keep the BIP-379 range
  1 <= N < 2^31: `<0> CLTV VERIFY` can never be spent
- Add LegacyInheritancePolicy for the `CLTV DROP` leaf, so vaults funded under
  it keep deriving their address and keep spending, including locktime 0 and
  the four-byte locktime push. Its miniscript spelling is
  `and_v(after_drop(N),pk(K))`: no standard miniscript compiles to `DROP`, so
  other tools reject the descriptor instead of deriving a different address.
  InheritancePolicy.toLegacy() converts an existing policy
- Read inheritance policies stored by earlier versions as the legacy leaf: JSON
  with `type: inheritance` and no `scriptForm` is a `CLTV DROP` leaf, in
  policies, vaults and wallets, with or without a stored tapTree. Policies
  written now carry `scriptForm: verify`
- Add TapTree.parseStored, which resolves a stored tree's inheritance leaves
  against the policies saved beside it
- Compile miniscript `after` and `older` to `VERIFY` instead of `DROP` in
  Miniscript.serializeForScript
- Add OP_VERIFY

Upgrading from 1.1.3:

- A vault funded before this release holds the `CLTV DROP` leaf. Restoring it
  from stored JSON (`Policy.fromJson`, `TaprootVault.fromJson`,
  `TaprootWallet.fromJson`) keeps its address. Rebuilding it from
  `InheritancePolicy(...)` or `InheritancePolicy.fromDescriptorAndLocktime`
  derives the new address instead, so use `LegacyInheritancePolicy` or
  `InheritancePolicy.toLegacy()` there
- Descriptors written by 1.1.3 and earlier spell the leaf like the new one, so
  they read as the new leaf; restore such vaults from JSON, or build them with
  `LegacyInheritancePolicy`
- `InheritancePolicy` addresses change for every locktime, not only below 2^23,
  because the leaf now ends in `VERIFY` instead of `DROP`

## 1.1.3

- Accept single signature and multisignature PSBTs that omit PSBT_GLOBAL_XPUB,
  such as those exported by BlueWallet
- Keep validating PSBT_GLOBAL_XPUB when it is present

## 1.1.2

- Fix WIF encoding to use Base58Check, and restore WIF decoding
- Support taproot script path policies: single signature and k-of-n multisig
- Support explicit taproot script trees with TapTree, TapLeaf and TapBranch
- Follow BIP-386 and BIP-390 in taproot descriptors; descriptor strings and
  their checksums change, addresses and signatures do not
- Keep reading descriptors and policies written by earlier versions
- Fix OP_NUMEQUAL from 0x87 to 0x9c, and add OP_EQUAL
- Fix PBKDF2 to hash the mnemonic bytes as given
- Estimate script path fees from the spent leaf's real merkle depth
- Accept auxRand for MuSig2 nonce generation
- Change TransactionInput.setTaprootScriptPathSpendingSignature to take a list
  of signature stack items

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

