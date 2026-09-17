# Consolidated chat history regression

Source: 8e2e9cf plus the bounded tombstone lookup change committed with this report.

History receipt persistence now fetches prior payloads in batches of at most 200 sequence parameters instead of one database query per incoming message. Terminal visibility remains resolved inside the same write transaction. A 450-message stale replay verifies preservation across three lookup batches and paginated reads.

The consolidated selection used all test paths matching `(chat|conversation|messaging|group|contact|friend|relay|outbox|draft).*_test.dart$`: 170 files, 956 passed, 0 failed, 10 skipped, elapsed 1m47s. Log: build/chat-batch-sept17-final.log. Dart analysis of the two changed Dart files passed. This selection does not cover every repository test. Skipped native/runtime-gated cases remain separate from prior explicitly enabled native evidence.

Includes local-first history search/context, access-denied cleanup, media receipt agreement, terminal visibility persistence, and the previous consolidated chat coverage. No UI changes or device installs; the latest built d44afcb APK predates these changes. Phone animation quality, public-network transport and unimplemented transaction features remain pending.
