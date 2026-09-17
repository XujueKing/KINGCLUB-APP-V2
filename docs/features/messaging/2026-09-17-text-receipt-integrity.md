# Text send acknowledgement integrity — 2026-09-17

Direct and group sends previously checked receipt identity but did not compare text payloads. A matching client ID with a different text or message type could remove the original durable outbox entry.

Both controllers now reject mismatched/missing text and non-text receipts before acknowledging the queued text. The original text remains available for retry under the same client ID. Legacy receipts without messageType remain supported. Recalled/hidden tombstones are still acknowledged without requiring deleted text; hidden messages stay invisible.

Validation: 50 tests passed across chat_text_receipt_test, direct_chat_controller_test and group_chat_controller_test. New cases cover both conversation types, content/type mismatch, missing text, corrected retries, normal receipts and tombstones. Static analysis passed. These are controller tests with supplied repository responses, not new live-server or device acceptance. No UI change, APK install or service deployment.

## History reconciliation follow-up

Applied the same text comparison to direct/group history batches before database commit and cursor advancement, and to the final acknowledgement path. Previously history could bypass send-response validation and delete a pending entry by sender/client ID alone. Incoming messages with an equal client ID do not confirm this account's outgoing queue.

Validation: 98 tests passed across text receipts, direct/group controllers, direct/group persistent history and nearby history reconciliation. An additional strengthened SQLite case passed with an explicit unchanged-cursor assertion: conflicting text leaves both the durable queue and the empty history intact, then a corrected response reconciles successfully. Static analysis passed for all changed Dart files. The old storage-reopen fixture was corrected to use the same queued text and returned text (hello), preserving its original storage-recovery purpose. These checks do not constitute live-device acceptance.
