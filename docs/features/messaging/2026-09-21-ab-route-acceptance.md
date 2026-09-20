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
The public relay/STUN changes remain staged and pending approval.

The next attachment test staged only the repository's `positioningCard.png` on B.
Before selecting or sending it, B's foreground changed to the separate Commerce
package. Its welcome screen is not evidence that the chat session was revoked.
Attachment routing verification was paused to avoid two sessions competing for
the same phone. No private gallery image was selected or sent.
