Script APIs model Bitcoin locking and unlocking scripts and the supported
policy language.

[Script](../coconut_lib/Script-class.html) is the decoded command representation.
[ScriptPublicKey](../coconut_lib/ScriptPublicKey-class.html) and
[ScriptSignature](../coconut_lib/ScriptSignature-class.html) represent output and input scripts. Use
[Miniscript](../coconut_lib/Miniscript-class.html) and
[Policy](../coconut_lib/Policy-class.html) implementations such as
[InheritancePolicy](../coconut_lib/InheritancePolicy-class.html) to express supported
Taproot script-path conditions.

These APIs operate on consensus-sensitive byte representations. Prefer the
typed constructors and parsers over assembling scripts manually.
