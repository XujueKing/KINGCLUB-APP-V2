# Scoped group file relay handshake

MemberRelayHandshake accepts an explicit service-validated group file scope.
The relay strips unknown application fields from native handshakes, confirmed
by a failed real WSS trial. Callers must obtain the expected scope separately;
no application hint is trusted or added to the native wire. Device lookups and renewals use
the group file permission and exact native key. Before exposing the channel,
both peers exchange the complete canonical scope inside native authenticated
encryption. A changed group/message/member epoch rejects the lane.

Confirmation retries for two seconds for late subscribers, but resolves as
soon as the matching encrypted confirmation arrives. It carries no file bytes.
Runtime automatic offer dispatch and downloader routing are still pending.
No UI or phone operations, no deployment, no claim of live group P2P delivery.

Validation: two native encrypted UDP scope-confirmation tests passed (delayed
peer and mismatched membership). Existing real SuperVM WSS integration passed
with added simultaneous group-scoped handshakes, followed by original direct
text recovery assertions (one consolidated test, 19 seconds). Directory HTTP
responses remain fixtures. Native DLL SHA256
B18317E2C587A58C45A6628FF58E86E13A9B0F2227778064FB56A8FB553DFC7C.
Temporary relay used explicit local CA at loopback port 45174 and was terminated
in finally. No keys or temporary configs committed. Four-file analysis passed.

The initial WSS trial timed out because extra relay handshake fields were
stripped. Removed that unsupported mechanism; no SuperVM protocol change.
Automatic incoming group offer discovery still requires an authenticated
out-of-band context association before runtime integration can be enabled.
