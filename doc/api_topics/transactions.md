Transaction APIs construct, estimate, serialize, parse, and validate Bitcoin
transactions.

A typical flow is:

1. Select one or more [Utxo](../coconut_lib/Utxo-class.html) objects.
2. Construct a [Transaction](../coconut_lib/Transaction-class.html) for a payment, batch payment, or sweep.
3. Convert it to a [Psbt](../coconut_lib/Psbt-class.html) before passing it across a signing boundary.
4. Finalize and validate the signed transaction before broadcast.

[TransactionInput](../coconut_lib/TransactionInput-class.html) models an outpoint and unlocking data.
[TransactionOutput](../coconut_lib/TransactionOutput-class.html) models an amount and locking script.
