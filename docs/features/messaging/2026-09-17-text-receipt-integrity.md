# Text send acknowledgement integrity — 2026-09-17

Direct and group sends previously checked receipt identity but did not compare text payloads. A matching client ID with a different text or message type could remove the original durable outbox entry.

Both controllers now reject mismatched/missing text and non-text receipts before acknowledging the queued text. The original text remains available for retry under the same client ID. Legacy receipts without messageType remain supported. Recalled/hidden tombstones are still acknowledged without requiring deleted text; hidden messages stay invisible.

Validation: 50 tests passed across chat_text_receipt_test, direct_chat_controller_test and group_chat_controller_test. New cases cover both conversation types, content/type mismatch, missing text, corrected retries, normal receipts and tombstones. Static analysis passed. These are controller tests with supplied repository responses, not new live-server or device acceptance. No UI change, APK install or service deployment.
