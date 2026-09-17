# Native relay batch and multi-interface receive fix

Enabled previously gated integration tests using the real Rust DLL and local SuperVM relay executable. The earlier local test TLS certificate was expired; verification correctly refused it. A separate seven-day self-signed certificate with localhost/127.0.0.1 SAN was created for this isolated run, explicitly trusted by test clients. Certificate verification was never disabled; existing certificate/key files were not replaced. Relay bound only 127.0.0.1:45173 and was stopped after testing. Private keys and runtime configs remain untracked build artifacts.

TLS here authenticates the WSS transport, not permission to join the blockchain. Node authentication independently pins the novovm-ed25519 peer identity; native secure UDP tests do not need the WSS certificate. This test does not establish public-mainnet or fully serverless delivery.

A real UDP rebind test reproducibly failed on this multi-interface host. After verifying advertised candidate IP, peer port, endpoint epoch and channel AEAD, the receive path additionally required the packet source to equal its own selected outgoing interface. Peers can choose different valid interfaces. Removed only that redundant equality check; readiness, candidate/port checks and authenticated decryption/replay rejection remain in place.

Evidence:
- Native signed-directory test passed (trust, tamper, capacity, sequence).
- Fresh-certificate relay batch: seven passed, one LAN rebind failure before the fix. Actual WSS handshake/opaque forwarding, file relay and foreground reconnect/primary routing passed.
- Fixed LAN rebind case passed in isolation.
- Final affected batch: ten passed, zero skipped, comprising real file transport/recovery, secure-session and UDP discovery/punch tests. Log build/chat-lan-final-check.log.
- File cases used 262161 bytes and covered lost final receipts and interrupted LAN with relay recovery. These elapsed times include injected faults; they are not bandwidth benchmarks.
- Source analysis passed. No phone install.

DLL SHA256 B18317E2C587A58C45A6628FF58E86E13A9B0F2227778064FB56A8FB553DFC7C
Relay exe SHA256 45719D4E62AEA463F699CAF0D02A0BD5669ED730F35FCFDFC7950C52FF4F6B1E

Remaining: authenticated HTTP fixture integration not enabled in this run; cross-network/mobile NAT, public mainnet, full application E2EE and phone-node routing remain pending. The previous APK predates this LAN fix.
