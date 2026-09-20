# A/B adaptive route acceptance

Device baseline: app `4eb93154` (profile ARM64); backend `164bf878`.
The backend now permits authenticated peer transport for reciprocal conversations,
consistent with ordinary chat authorization. It still rejects blocked peers,
unanswered unilateral conversations and revoked/current-device mismatches.
No member relationship records were changed for this check.

## Observed on the two authorized test phones

| Check | Evidence / result |
| --- | --- |
| B to A LAN text | Local test relay temporarily suspended. Message visible on A before resume; relay frame count stayed 40. Matching durable peer-journal ID on both devices; B delivery receipt persisted. |
| A to B LAN text | Same procedure, frame count stayed 44. Matching peer-journal ID and A delivery receipt persisted. |
| Relay outage fallback | Stopped only the local test relay. New B message appeared on A while relay remained stopped. Peer-journal counts did not increase, consistent with the service fallback. |
| Automatic reconnect | Restarted the same relay/configuration. Both authenticated sessions returned without login or page restart. A subsequent B message had matching peer journals and a persisted delivery receipt. |
| Direct recovery stability | Not accepted yet. Two later pause checks displayed the messages but did not add peer-journal rows. Display alone is not proof of direct delivery; these used service fallback. |
| Image UI delivery | Sent the repository's package illustration through B's system photo picker and send confirmation; image rendered on A. This does not independently prove the image bytes used UDP rather than HTTP. |

Relay suspension was bounded and resumed in `finally`; the stopped relay was
restarted in `finally`. Cloud chat/Commerce services and phone network settings
were not changed. No private user photo was selected. Screenshots and encrypted
database snapshots remain local under ignored `build/`; only journal metadata
was queried, without decrypting messages or extracting session keys.

## Deadline correction

Inspection found a nested 1.2-second device timeout inside the existing 2.5-second
overall peer-send budget. The inner timer also counted fresh directory queries,
live authorization and handshake work, and could enter cooldown even when the
receipt would fit within the overall budget. Remove that inner timer and retain
the overall deadline, active-attempt fences, stable message IDs and HTTP fallback.
This is a concrete source of premature fallback, not yet a proven explanation
for every observed device fallback.

Validation: nine adaptive-route tests passed, including an 1.8-second receipt
that preserves the next peer attempt and the existing 2.5-second timeout fence.
The native dropped-handshake/receipt text case and five reconnect cases passed.
Two environment-gated live runtime cases were skipped and are not counted as
passes. Static analysis reported no issues. Device installation and repeat
acceptance of this deadline correction are recorded separately when completed.

## Remaining external acceptance

Public STUN UDP 3478 ingress was approved and verified from the PC and both
phones on 2026-09-21. The staged public WSS proxy remains pending approval.
The current relay is LAN-only; these results do not establish cross-carrier
punching, public relay deployment, decentralized discovery or untraceability.
B has no usable cellular connection in this session. Media-route selection and
stable direct recovery still require explicit evidence.
