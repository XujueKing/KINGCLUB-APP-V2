# A/B route recovery acceptance

Both authorized phones returned `Success` for an in-place installation of the
preview recorded in `2026-09-21-peer-budget-build.md` (source `76a793e8`).
Both opened their existing signed-in accounts and original mutual conversation.
No app data, credentials or message history were cleared.

## Completed checks

1. Sent a new B-to-A message to establish the peer channel. Both local encrypted
   databases acquired matching peer-journal IDs; B persisted its delivery receipt.
2. Suspended the local test relay, then sent another B-to-A message. Before relay
   resume, both databases acquired the same new ID and B persisted its receipt.
   This proves LAN carriage for this message, not just a successful UI display.
3. Stopped the local test relay. A received the next B message while the relay
   remained stopped; neither peer journal increased. Service fallback worked.
4. Restarted the same relay configuration. Both authenticated sessions returned
   without a page restart or login. A new message acquired matching peer journals
   and a durable sender receipt.
5. Suspended that recovered relay and sent three consecutive B-to-A messages.
   Before resume, all three matching IDs existed at both endpoints and all three
   sender receipts were durable. Unlike the previous build's observed checks,
   these subsequent sends did not drop into service fallback.
6. With the established channel still alive, suspended the relay again and sent
   A-to-B. Its matching IDs and A's durable delivery receipt were present before
   resume, confirming the reverse direction.

Across these checks, peer-journal row counts grew from six to thirteen on each
device (seven matching peer messages); the separate HTTP fallback message was
not counted as a peer success. Database inspection selected only IDs, direction,
receipt state and timestamps, not message payloads or encryption/session keys.
Every suspension used a `finally` resume; the stop test used a `finally` restart.
Cloud chat and Commerce services, account relationships, and phone network
settings were unchanged.

## Scope and remaining work

This accepts the tested text recovery scenario on the current same-LAN A/B pair.
It is not a cross-carrier, public-STUN, prolonged-loss or mobile-background test.
UDP 3478 has since been approved and opened, with STUN responses verified.
The public WSS relay entry remains pending approval; opening STUN alone is not
evidence of cross-network peer connectivity.

The next attachment test staged only the repository's `positioningCard.png` on B.
Before selecting or sending it, B's foreground changed to the separate Commerce
package. Its welcome screen is not evidence that the chat session was revoked.
At that earlier checkpoint, attachment verification was paused to avoid two sessions competing for
the same phone. No private gallery image was selected or sent.

## Subsequent attachment evidence (2026-09-21)

B was subsequently assigned to chat testing. See the linked records for hashes,
timestamps and limits; these checks do not replace public-network acceptance.

| Actual path | Verified result | Remaining scope |
| --- | --- | --- |
| File | 8 MiB automatic peer→HTTP missing-block resume; next file after B restart completed via peer; 2 MiB authenticated ingress includes UDP and relay | Public network, sustained-loss performance |
| H.264 / HEVC video | Both codecs received over UDP with matching persistent hashes and decoded end frames; 20-second H.264 automatically resumed through HTTP after B stopped; cfbbe494 reduced observed handoff from ~9s to ~4s and reused 1 MiB in the second run | Public-network interruption, incomplete-block repair efficiency, unsupported-HEVC device fallback, human audio confirmation |
| Voice | Actual 3-second recording received as 20 UDP frames, relay=0; both devices' persistent hashes match | Cross-network/background paths; this run did not assess listening quality |
| Image | Full 3618-byte image received via encrypted peer relay; display and hash match | Explicit image UDP, larger-image interruption |

Detailed records: [file resume](2026-09-21-peer-cancel-resume.md),
[video](2026-09-21-canonical-video.md), [voice](2026-09-21-canonical-voice.md),
[image](2026-09-21-canonical-image-fix.md). The installed observation build is
d3ff0aab; see [stall probe and phone verification](2026-09-21-peer-stall-probe.md)
and [prefix repair verification](2026-09-21-prefix-repair.md) for APK hashes,
measured recovery timing and the latest 2 MiB cache reuse result.
