# Real member HTTP and native transport — 2026-09-17

App source 6ca9aec (production Dart code unchanged from 6a137d3). Enabled the previously gated HTTP integration with real authenticated encrypted CCSOP calls, Rust native library, local SuperVM WSS relay and SQLite histories.

Isolated backend: existing peer-file-authority-118-test image, dedicated kingclub_chat_test_20260913 database, unique Redis prefix and temporary container kingclub-native-current-test. Port published only on server loopback 39183 and accessed through local SSH loopback 39184. Existing online API container was not replaced. Tests generated synthetic approved members, never used A/B or other real members. Fixture host had a 300-second automatic cleanup deadline.

## Verified

- member_relay_http_test passed against real device-key registration, resolution and member authorization.
- Authenticated native relay delivered text to receiving SQLite before ordinary service submission. Service reconciliation returned sequence; same client ID replay returned the same message ID; receiving history contained exactly one corresponding record.
- Actual 4097-byte file uploaded and sent using real endpoints. Authorized native relay download matched original bytes and made zero HTTP chunk requests. After sender cache removal, a subsequent download matched bytes through ordinary HTTP fallback.
- Device-key revocation caused revalidation and subsequent sending to fail.
- native_rendezvous_http_test passed with a fresh independent fixture: real encrypted HTTP directory, offer/answer, native authenticated payload, replay rejection and cancellation.

The first combined invocation passed the member relay test but failed the next test because both tried fresh native keys under the same fixture device identity. The fixture was stopped (revoking its sessions) and restarted with new synthetic actors; the rendezvous test then passed. These tests require independent actor/device fixtures when run together; do not describe the combined first invocation as green. Logs: build/chat-member-http-current.log and build/chat-native-http-current.log.

## Cleanup and limits

Fixture container stopped cleanly; remote fixture removed; independent SQL check reported SYNTHETIC_NATIVE_ACTIVE_SESSIONS_ZERO. Local credential fixture deleted; owned SSH tunnel and local relay processes stopped. Private sessions/keys were not committed. No phone install or live service deployment.

Existing native DLL and separate explicitly trusted self-signed localhost certificate from the prior native batch were reused. Native library SHA256 and relay executable provenance remain in 2026-09-17-native-relay-batch.md. This tests a loopback WSS transport through real member APIs; it is not mobile/public NAT verification, a public mainnet, full message E2EE or persistent production outbox acceptance (the test's outgoing queue is in memory). No claim that all ten cases skipped in the broad regression have now passed.
