# Public SuperVM WSS entry

The operator explicitly approved enabling the public WSS path on 2026-09-21.
Activated only `location = /supervm/relay` in the existing test.wuyexin.cn
443 TLS server. It proxies to https://127.0.0.1:45172/novovm, verifies the
upstream certificate and hostname localhost, permits WebSocket upgrade, and
disables this location's access log. Other business locations are unchanged.

Before writing, the active site SHA-256 was checked against
`d0cf6dc519caf8c9d2cf1f8fe78c98bf583233fe19d774ebe50904281bddd67e`.
Backup: `/etc/supervm/nginx-before-public-1789969624.conf`.
After insertion: `d804ca14e1237b4855056a32564e8a3c658f0565dc1dbff442c5ed5a94608625`.
`nginx -t` and reload succeeded. A desktop ClientWebSocket with normal system
TLS validation connected to wss://test.wuyexin.cn/supervm/relay with State=Open.
This proves TLS/WebSocket reachability, not member authentication or public UDP.

Cloud node identity remains pinned to
`novovm-ed25519:cf90edfde780311f3daee22e39403c07a06ae577f43c3ab5155ff41e562961f2`.
No consensus code or private keys were modified. The prepared client build uses
system public roots rather than the former LAN relay's private certificate.

A reconnected by USB and now has a SIM. Inspection found it initially still
using the original Wi-Fi despite a connected mobile network. Disabled A Wi-Fi
for the authorized cross-network test; default network changed to validated
MOBILE[NR]/cmnet. B remains on the original Wi-Fi. These supersede the previous
no-SIM and WSS-approval blockers, but do not themselves prove peer connectivity.

## Installed build and first cross-network checks

A/B both installed the f2fc5b70 public-endpoint profile build successfully.
APK SHA-256: `c314f6bbf4d976460657d9e5babe14710f411615ed84ca6a3d7bfb081872abc5`.
Build took 124.0 seconds; both existing test accounts remained signed in.

At 13:53:37 B sent a synthetic text. Both peer journals acquired
`118b7ee6-4b8e-4bab-999f-6fe2a6130e14`; B stored delivered=1 and A displayed it.
This confirms authenticated cross-network peer carriage, not its UDP subtype.

The first image selection returned to chat without showing the preview and
coincided with a device-binding AuthFailure/retry. Reselecting succeeded.
No cause is asserted from this coincidence; selector/session behavior remains
an observation to investigate if reproduced.

Synthetic image message `e88bd077-8f1e-4e2d-b78c-1aab4d07cbe2` used the same
3,310,848-byte canonical WebP as the earlier interruption test. B logged image
source-ready at 13:57:42.528; A completed at 13:58:35.854 with UDP=0 and relay
5,070 frames / 4,947,600 bytes (including retransmissions). Its two persistent
full-image entries match SHA-256
`d862c9b89320beabd7a3bf8d8d135517861ca39ef7ea593d9eb6d05f21b2e773`.
Server access logs for this message contain only the 3,860-byte thumbnail GET,
not the full image. Logs also establish different public client exits for A/B;
the addresses are not recorded here.

Public encrypted-relay delivery passes this check. Public UDP direct carriage
does not: its count is zero. The roughly 53-second image transfer is not accepted
as a performance target. Next work is to diagnose candidate/mapping/probe behavior
and carrier NAT restrictions, then verify recovery/interruption on this topology.

## UDP investigation

At 14:01 the cloud interface observed one 20-byte STUN request from each of
the two distinct test exits and sent a 40-byte response to each. The bounded
capture ended by timeout; it did not observe arbitrary chat traffic. This
establishes server-side STUN ingress/egress, not phone-side response acceptance.

Added non-release aggregate NovoRoute counters: accepted STUN replies, mapping
presence, candidate counts, sent probes, authenticated pings, nonce-accepted
pongs, rejected same-IP/different-port packets and invalid packets. A snapshot
is logged after roughly ten seconds and then every thirty seconds. No IP,
member ID, nonce, key or chat payload is logged; release emits no snapshots.
Routing and authentication decisions are unchanged. Static analysis and five
discovery/failover/nonce regression checks passed. The counters are intended to
locate the current direct-route failure before changing its trust boundaries.

## Route observations on both actual devices

Both independent phone STUN probes returned valid 40-byte binding responses.
Installed 4501c248 on A/B, both install-r Success; APK SHA-256
`9a3210360f1d2418f94586e5b9818ac43d111e6e93cf6bcfeb9cf1717662bc9d`.
Public relay, existing accounts and A-cellular/B-Wi-Fi topology were retained.
New text peer ID `a4e76888-e409-4dc5-ac4a-a2cdfd4a4791` matched both journals
and B persisted delivered=1.

At 14:08:23 both route snapshots reported mapped=true, stunReplies=1,
candidates=1, publicCandidates=1, ready=false. A had sent 20 probes and B 18.
Both reported pingReceives=0, pongReceives=0, portMismatches=0 and
invalidPackets=0. This establishes that mapping and authenticated candidate
exchange succeeded, but no valid incoming probe was observed on either endpoint.
It does not prove a particular NAT type or deliberate carrier blocking. In
particular, there is no observed same-IP/different-port packet to justify
loosening the source check as a fix for this trial.

Continue with fallback/recovery under this unreachable direct-path topology and
the observed slow relay attachment path. Direct UDP on this topology remains
unaccepted; encrypted relay success must not be relabeled direct success.
