# A/B foreground route recovery

Actual phones used the unchanged 882e422b preview on the same LAN. Only the
authorized test pair exchanged synthetic text markers. App data and login
state were retained; no cloud configuration changed.

1. Sent B to the Android home screen. A sent a text, then B was brought back
   during delivery. Both peer journals acquired ID
   `9c763635-a08e-4e0b-ac84-948a5aef0717`; A's outgoing row had delivered=1.
   This is evidence of peer delivery across a short foreground transition,
   not evidence of HTTP fallback or durable background reception.
2. Sent B home again and kept it there. A submitted the next marker at
   08:23:57. Both peer journals remained at 14 entries. B was subsequently
   foregrounded; its list and conversation displayed that marker through
   service synchronization, with peer counts still unchanged. No retry or
   refresh action was used. This checks service fallback while the recipient's
   foreground peer runtime is unavailable, not OS notification delivery.
3. B sent a new marker at 08:25:12. Both peer journals grew to 15 entries,
   with matching ID `42e38ebc-f7b1-4221-802a-bf7fade87691`; B's outgoing row
   had delivered=1. No app restart or login was required to recover peer use.

Code review confirms MemberRelayRuntime closes peer links on leaving resumed,
invalidates pending connection attempts, and reauthenticates on return.
The existing regression checks for backoff, background retry cancellation,
late handshake completion and account changes, together with adaptive text
route tests, passed: 14 tests. No code change was needed for these scenarios.

Journal inspection selected only IDs, direction, delivery flags and timestamps;
encrypted content and key material were not read. These journal rows prove
authenticated peer transport, but do not distinguish UDP from encrypted relay
carriage. This does not accept prolonged OS suspension, process eviction,
background push, public cross-network NAT traversal, or independent-carrier
recovery. Those scopes remain outstanding.

## Public-network follow-up, 15:27–15:33

Both phones ran a6cd895d. A used cellular data and B used Wi-Fi, with the
approved public WSS relay. A was sent to Android Home at 15:27:08 and brought
back at 15:29:08. Its PID remained 19739 at 0, 30, 60, 90 and 120 seconds.
B sent the synthetic `KC-BACKGROUND-PUBLIC-1527` marker during this interval.
After return, A's conversation displayed it without a refresh action; the
peer journal counts were unchanged (A 19, B 20). This is service synchronization
after backgrounding, not a claim of background peer delivery.

A then sent `KC-RETURN-PUBLIC-1530`. Both journals acquired
`c1382ce8-1bd1-42f1-9efc-65eb5a7dbedc`, A outgoing delivered=1, and B's actual
conversation displayed the marker. Peer communication recovered without
restarting or logging in again. A's route diagnostics still reported ready=false,
one public candidate, zero accepted ping/pong and zero port mismatches, so this
does not establish public UDP direct connectivity.

This extends the earlier foreground recovery check to different networks and
a two-minute retained process. It does not cover Doze, OS eviction or background
notifications. No application code or server configuration was changed.

Diagnostic limitation found during review: the current UDP receive filter counts
same-address/different-port packets, but discards unknown source addresses before
authentication without a counter. Zero accepted probes therefore cannot establish
that no UDP datagrams arrived at all, nor identify the NAT or carrier policy.
