[Psbt](../coconut_lib/Psbt-class.html) implements the Partially Signed Bitcoin Transaction exchange format
defined by BIP174, including SegWit v0, Taproot, and MuSig2 metadata used by
this package.

Use [Psbt.fromTransaction](../coconut_lib/Psbt/Psbt.fromTransaction.html) to create a signing request from a transaction and
wallet policy. Parse an external PSBT only at a validation boundary, confirm it
matches the expected vault, and validate every signature before finalization.

[PsbtInput](../coconut_lib/PsbtInput-class.html) and
[PsbtOutput](../coconut_lib/PsbtOutput-class.html) expose decoded per-map metadata.
[DerivationPath](../coconut_lib/DerivationPath-class.html) associates public keys with BIP32 origins.
