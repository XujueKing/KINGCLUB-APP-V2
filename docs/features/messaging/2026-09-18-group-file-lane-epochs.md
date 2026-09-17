# Group file lane membership versions

The file channel now retains the complete group scope established during the
native encrypted handshake. Every file grant, including the first grant on a
reused lane and periodic renewal, must match the original group, message,
sender, recipient and both membership versions. A fresh grant with a newer
membership version cannot silently authorize an old lane. The caller can
establish a new scoped lane or use the existing service download fallback.

Previously the runtime distinguished lane versions, but the file channel kept
only group/message IDs. Permission changes between handshake and first request
were therefore not compared to the handshake's scope. The constructor now
accepts the scope object rather than separate optional IDs, preventing callers
from dropping its versions.

Validation: seven encrypted UDP file negotiation cases passed using the real
native DLL, including successful private/group transfer, missing cache, wrong
sender, mid-request membership change, and stale sender/recipient versions on
both channel endpoints. Stale initial grants emit zero UDP packets. Dart analysis
of the two implementation files and test passed. HTTP grants are fixtures;
this is not phone acceptance or a combined live service transfer. The group-file
flag remains default-off; no UI changes or phone installation.
