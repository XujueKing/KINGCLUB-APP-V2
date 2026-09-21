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
