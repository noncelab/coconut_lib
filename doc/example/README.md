# Examples

These self-contained examples run on regtest and do not connect to a Bitcoin
node. The transaction IDs and amounts are illustrative only; never reuse the
mnemonics or keys in a real wallet.

## Run

From the repository root:

```sh
dart run doc/example/single_signature.dart
dart run doc/example/multisignature.dart
dart run doc/example/taproot_script_path.dart
```

## Contents

- `single_signature.dart`: creates a watch-only wallet from a vault descriptor,
  builds a PSBT, signs it in the vault, and finalizes the transaction.
- `multisignature.dart`: exchanges BSMS records and coordinates two independent
  signers for a 2-of-3 P2WSH transaction.
- `taproot_script_path.dart`: demonstrates Taproot MuSig2 key-path signing and
  inheritance-policy script-path signing.
