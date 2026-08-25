Domain exceptions expose stable error codes that callers can handle without
matching human-readable messages.

[CoconutException](../coconut_lib/CoconutException-class.html) is the common base type. Catch the narrowest applicable
exception—[WalletException](../coconut_lib/WalletException-class.html),
[TransactionException](../coconut_lib/TransactionException-class.html),
[PsbtException](../coconut_lib/PsbtException-class.html), or
[SigningException](../coconut_lib/SigningException-class.html)—and inspect its `code` for programmatic handling.
