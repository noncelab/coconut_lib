Wallet and key APIs create signing vaults or public-only watch wallets.

Start with [SingleSignatureWallet](../coconut_lib/SingleSignatureWallet-class.html),
[MultisignatureWallet](../coconut_lib/MultisignatureWallet-class.html), or
[TaprootWallet](../coconut_lib/TaprootWallet-class.html) for watch-only address derivation. Use the corresponding
vault type when private seed material and signing are required.

Common supporting types:

- [Seed](../coconut_lib/Seed-class.html) creates or imports BIP39 seed material.
- [KeyStore](../coconut_lib/KeyStore-class.html) associates an account extended public key with its fingerprint.
- [Descriptor](../coconut_lib/Descriptor-class.html) imports and exports wallet policies.
- [Utxo](../coconut_lib/Utxo-class.html) identifies spendable transaction outputs.

Complete examples are available in the repository:

- [Single-signature workflow](https://github.com/noncelab/coconut_lib/blob/main/doc/example/single_signature.dart)
- [Multisignature workflow](https://github.com/noncelab/coconut_lib/blob/main/doc/example/multisignature.dart)
- [Taproot script-path workflow](https://github.com/noncelab/coconut_lib/blob/main/doc/example/taproot_script_path.dart)
