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
| Image | Small/full images via peer relay and UDP; 3,310,848-byte image automatically resumed through HTTP after B stopped, reused 2 MiB, persistent hashes match | Cross-network/background paths |

Detailed records: [file resume](2026-09-21-peer-cancel-resume.md),
[video](2026-09-21-canonical-video.md), [voice](2026-09-21-canonical-voice.md),
[image](2026-09-21-canonical-image-fix.md). The installed observation build is
882e422b; see [image lane phone verification](2026-09-21-media-lane-contention.md),
[stall probe and phone verification](2026-09-21-peer-stall-probe.md)
and [prefix repair verification](2026-09-21-prefix-repair.md) for APK hashes,
measured recovery timing and the latest 2 MiB cache reuse result.

Actual larger-image interruption evidence: [automatic image resume](2026-09-21-image-auto-resume.md).

Actual short foreground/background transitions, service fallback and subsequent
peer recovery: [background route recovery](2026-09-21-background-route-recovery.md).
This does not cover OS eviction, prolonged suspension or background push.

## Earlier public-network prerequisite checkpoint (superseded below)

After installation of f2fc5b70, both authorized USB devices remain connected.
Both report `gsm.sim.state=ABSENT,ABSENT`. A's mobile-data setting is enabled,
but that setting alone does not establish an available cellular connection.
Neither phone currently provides the required independent-carrier test path.

The cloud SuperVM service is active, and `nginx -t` succeeds. The active site
configuration still has no `/supervm/relay` location; its SHA-256 remains
`d0cf6dc519caf8c9d2cf1f8fe78c98bf583233fe19d774ebe50904281bddd67e`.
The prepared location uses the existing 443 listener and verifies the private
relay's TLS certificate. Its activation remains pending the requested operator
confirmation, distinct from the already approved UDP 3478 ingress.

The operator has been asked to confirm this exact WSS path and provide an
independent mobile hotspot for B while A remains on the current Wi-Fi.
Without those conditions, no public cross-network peer, interruption or recovery
acceptance is claimed. Repeating same-LAN checks cannot close this requirement.

## Current public-network checkpoint

The operator subsequently authorized public WSS and connected A through cellular
data. The WSS path is active; A cellular/B Wi-Fi was verified on both devices.
The earlier missing-authorization/missing-independent-network blockers above no
longer apply. See [deployment](2026-09-21-public-wss-deployment.md).

The earlier e8175015 installation evidence is retained below; see the latest checkpoint at the end for current builds. Public encrypted-relay text
and images, automatic image HTTP fallback with matching persistent digest,
slow-relay handoff, and text reception on an attachment-initiated lane have
actual device evidence. See [slow relay](2026-09-21-slow-relay-handoff.md) and
[text after attachment](2026-09-21-text-after-attachment.md).

Public UDP probes still receive no incoming peer packets on this topology;
do not relabel relay delivery as direct UDP. Public file transfer now has
process-stop/reopen evidence for reuse of two complete cached blocks, and video
has actual sender-interruption automatic HTTP fallback plus full decoding.
See [public interruption](2026-09-21-public-interruption.md). The file test
includes a manual reopen; the video interruption had no complete block to reuse.
Cross-network voice now has peer-relay delivery, sender-offline HTTP fallback,
and receiver-offline local player evidence; see [public voice](2026-09-21-public-voice.md).
Human audio quality, prolonged background/OS-eviction behavior and public UDP
direct carriage remain unaccepted. LAN and automatic tests do not replace them.

## Consolidated current evidence

| Goal requirement | Current evidence | Limit |
| --- | --- | --- |
| Peer-first text, fallback and recovery | Actual A/B LAN UDP with relay suspended; service fallback while relay stopped; durable peer receipts after restart; public WSS text | Public phone-to-phone UDP remains unaccepted |
| Shared UDP/HTTP media blocks and resume | Actual LAN image/video/file interrupted transfer reuses verified complete blocks; public 8 MiB file reopens after process stop and requests only missing blocks | Public file process-stop case requires reopening; not automatic background restart |
| Images | Canonical complete image digests match; public slow-relay handoff to HTTP | Public UDP image unavailable in current topology |
| Voice | Actual LAN UDP; public encrypted relay; sender-offline HTTP; receiver-offline local playback | New runs verify transport/player execution, not human audio quality |
| Video | Actual LAN H.264/HEVC UDP and decoding; public sender-interruption automatic HTTP recovery and decoding | Public interruption had no complete cached block; unsupported-HEVC hardware not tested |
| Stable return from background | Actual public two-minute retained-process return, service sync, next peer message acknowledged | Not Doze, process eviction or background push |
| NAT port changes | Real sockets with native authenticated channel: observed port requires nonce return probe; 10 related checks passed | Actual phones see no inbound probe to trigger learning; does not guarantee traversal of all NATs |
| GitHub delivery | Code e8175015 and device evidence 8bcb4af9 pushed | This matrix is a later documentation update |

See [observed UDP port](2026-09-21-observed-udp-port.md) and the public follow-up
in [background recovery](2026-09-21-background-route-recovery.md).

The remaining public-direct investigation currently needs the Wi-Fi gateway's
WAN/reachability state. Gateway HTTP responds, but the browser control channel
times out reading its existing tab. Explicit WLAN-interface IGD discovery returned
no response; the NAT-PMP address-query attempt encountered a UDP socket reset.
Neither observation proves a particular NAT type or that the WAN lacks a public
address. No router settings were changed. The operator was asked for the WAN
address category, without credentials. There is no reason to reinstall the same
build or repeat already accepted LAN media tests while that prerequisite is unknown.

## Gateway inspected after operator reopened the page

Browser access recovered. The authenticated gateway information page shows a
WAN IPv4 in `100.64.0.0/10`, a globally scoped WAN IPv6, and model HN8141N
(no built-in Wi-Fi). Do not publish the complete WAN addresses or device serial.
The mapping list has no entries. The available LAN settings expose IPv4 address,
mask and DHCP range only; no IPv6 delegation/RA control was visible.

At the same checkpoint, B's actual `wlan0` has only a `fe80::/64` link-local
IPv6 address. Thus the gateway's WAN IPv6 does not establish an IPv6 path for B.
The shared IPv4 WAN is not directly globally routable (RFC 6598); adding a
mapping on this gateway alone does not configure the upstream carrier NAT.
This is not proof that all UDP punching through the carrier is impossible, nor
proof of its filtering policy. Existing direct probes remain unaccepted.

No router settings were changed. A controlled public IPv4 entry needs carrier
provisioning/upstream mapping; an IPv6 alternative needs LAN delegation and a
client global IPv6 addresses. The route now supports optional IPv6; B still lacks a global IPv6 address.
Reference: https://www.rfc-editor.org/rfc/rfc6598.html

## Latest checkpoint: bf74a7fd

Both phones installed bf74a7fd profile APK, SHA-256 `f127d32417d138041656879fc650f75e028e1595f2547bd6a10fac3dd4f821d9`.
Actual message `eef047cb-144e-4ef1-a1ab-02315487bf6c` is present in both peer journals with sender delivered=1. This is post-install messaging evidence, not forced socket-closure recovery evidence.

- Optional global IPv6 discovery and closed-socket handling: [IPv6 evidence](2026-09-21-ipv6-candidates.md).
- The actual WebRTC call on the same A cellular/B Wi-Fi topology selected UDP relay, with increasing bidirectional counters: [ICE comparison](2026-09-21-ice-comparison.md). This does not prove all direct traversal impossible.
- The parent peer lane now retries missing/closed UDP routes while preserving its secure relay session: [route reopening](2026-09-21-udp-route-reopen.md). Twelve targeted tests passed; the existing native encrypted LAN unreachable-candidate/rebound-socket regression also passed. Phone-level forced IPv4 socket closure recovery remains unverified.
- Public direct acceptance remains open. B's current Wi-Fi lacks a global IPv6 address; operator availability of B cellular data was requested for an alternate topology. No network switch was performed without an answer.

Historical router-access and IPv4-only implementation limitations above are superseded by the gateway inspection and IPv6 implementation records. No claim of fully completed public peer-to-peer transport is made.
