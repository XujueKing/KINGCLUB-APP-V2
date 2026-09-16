# Unopened conversation voice retention

The live conversation-list refresh now schedules changed unread conversations
for voice-only history queries. It does not call read/mark-read APIs. Identical
conversation sequences are skipped, and a newer sequence arriving during a
query stays queued. History and voice downloads are serialized; account changes
dispose the queue and discard late history responses.

Each query requests at most 50 recent voice messages. Queue/version/retry state
is bounded to 50 loaded conversations. Existing saved files avoid downloading
again. Failed queries or incomplete retention remain retryable after a 30-second
backoff on a subsequent list update; they are not recorded as completed.

Ten worker/inbox/list regression tests passed and analyzer passed four changed
source/test files. Tests use synthetic APIs/cache and validate same-sequence
deduplication, newer updates during a query, late-result disposal, saved asset
reuse, media permission/session handling and unchanged cached-list behavior.

Not installed or phone accepted yet. This operates while the conversation list
is mounted and receiving refreshes, not as an OS background download service.
Older messages, conversations outside the loaded recent window, app-terminated
delivery and reliable locked-screen processing remain outside this increment.
The full offline synchronization requirement is still incomplete.
