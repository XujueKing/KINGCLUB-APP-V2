# Consolidated chat regression — 2026-09-17

Source: 6a137d37a3a485cab8da6215426262deaa6a6923.

Result: 856 passed, zero failed, 10 skipped. Elapsed 2m38s. Flutter test process exited 0. Full local log: build/chat-batch-current-tests.log.

Selection: 166 tracked/local test files returned by rg --files test whose paths matched `(chat|conversation|messaging|group|contact|friend|relay|outbox|draft).*_test\.dart$`. This is the named messaging regression selection, not every repository test. Existing unrelated onboarding edits were not committed or changed. No dependency, production service or device was modified for this run.

Coverage includes direct/group controllers and receipt integrity, encrypted history and deletion, media/draft retention, offline queues, current composer golden images, relationships and group flows. Previously reported failures in the older broad run do not recur in this selection, including large retained-file restoration and the corrected current-panel baselines.

The 10 gated tests were not enabled in this invocation. Native library, live relay and authenticated HTTP fixture prerequisites remain distinct from ordinary controller/widget tests. Separate real Rust/WSS/UDP runs and their narrower scope are documented in 2026-09-17-native-relay-batch.md; do not turn this batch's skips into passes using those older results.

No new Android APK built or installed. Phone A/B acceptance of recent changes, public-network NAT/relay fallback, full application E2EE, device-node routing and remaining transaction features are still incomplete. See the delivery matrix. This report records regression evidence, not completion of the whole messaging goal.
