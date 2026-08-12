# Coconut library design

These diagrams describe the security boundaries and major object relationships
of `coconut_lib`. PlantUML (`.puml`) files are the source of truth. Files under
`generated/` are rendered artifacts for repository viewers.

## Diagrams

- [Wallet–Vault security boundary](generated/wallet_vault_boundary.png)
- [Wallet class model](generated/wallet_class_diagram.png)
- [Exception model](generated/exception_model.png)
- [Transaction and PSBT model](generated/transaction_model.png)
- [PSBT signing flow](generated/signing_flow.png)

## Design rules

- A `Wallet` is watch-only and accepts public-only `KeyStore` instances.
- A `Vault` may retain seed/private-key material and performs signing.
- A `Psbt` is the interchange object between wallet construction and vault
  signing. A vault validates policy and prevout metadata before signing.
- Malformed serialized input throws `FormatException`; invalid caller
  arguments throw `ArgumentError`/`RangeError`; invalid object state throws
  `StateError`; recoverable domain failures use `CoconutException` subtypes.
- Taproot MuSig2 secret nonces are signer-local, single-use secrets and are not
  serialized into the PSBT.

## Rendering

PlantUML and Graphviz are required. From the repository root, run:

```sh
plantuml -tpng -o ../generated doc/design/architecture/*.puml
plantuml -tpng -o ../generated doc/design/transaction/*.puml
```

Review and commit both the `.puml` source and regenerated PNG files.
