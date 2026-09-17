# Actual native transport consolidated validation

App source e672b2f plus unrelated untouched onboarding worktree edits. Ran 18 selected test files: all novorudp*_test.dart except novorudp_datagram_link_test.dart (requires a separate Rust fixture executable), nearby_peer_connector_test.dart, supervm_live_relay_test.dart and supervm_relay_file_test.dart. Tests run sequentially with the real native DLL and an actual local SuperVM relay daemon. Result: 72 passed, zero skipped, zero failed, 3m08s. This is separate from the prior generic 180-file selection; do not add counts as unique cases.

Native DLL SHA256: B18317E2C587A58C45A6628FF58E86E13A9B0F2227778064FB56A8FB553DFC7C.
Relay executable SHA256: 45719D4E62AEA463F699CAF0D02A0BD5669ED730F35FCFDFC7950C52FF4F6B1E.
Relay bound 127.0.0.1:45173 using the existing explicit local test CA and pinned node identity, not public CA authorization. Process 20848 was started only for this batch and terminated in finally after tests completed. No phone installation, no production deployment, no trust-store changes.

Coverage includes native device identity/binding/bootstrap, signed peer handshake, encrypted UDP sessions, repair/retry/file transfers, real WSS relay opaque ciphertext, local LAN candidate fallback and socket rebinding, plus file completion after lost final receipt with relay/LAN/interrupted-LAN cases. Some unit fixtures accompany the native integration paths; do not describe every individual assertion as a production network test.

Recorded deterministic loss test: 18,874,368 bytes, 81,103 ms, 25,484 packets and 3,595 intentionally dropped packets. File integrity and single delivery assertions passed. The 68,341-byte loss case took 633 ms with 15/100 packets dropped. These are local fault-injection runs, not normal-network bandwidth or phone-performance benchmarks.

Logs remain local: build/native-batch-relay-tests.log (UTF-8), build/native-batch-relay-stdout.log, build/native-batch-relay-stderr.log. Temporary config/identity/keys were not committed. The real member HTTP/runtime test files are not in this selection. Public Internet NAT traversal, mobile automatic routing, deployed bootstrap nodes and full decentralized availability remain unverified.
