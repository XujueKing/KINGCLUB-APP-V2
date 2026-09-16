# Pending message media references

Production ChatHistoryStore opens the current account's SecureChatOutbox. Before
explicit media deletion, it reads pending rows and preserves referenced voice
assets, sent-file assets and own image/video client-message source copies.
History invalidation without media deletion does not read the queue. A queue read
failure propagates before deleting history. Pending rows themselves are kept.

39 history/cleanup/direct/group history tests passed. The new real SQLite/disk
test clears saved rows while a supplied outbox still references their voice and
own image source, verifies both files remain and verifies the queue is unchanged.
The test outbox is in-memory; it does not prove Android secure-storage behavior.

This is a queue snapshot, not an atomic transaction across secure storage and
SQLite. Concurrent new sends and deferred deletion after queue completion still
need durable ownership handling. Legacy transport aliases and phone acceptance
remain outstanding. No APK installed for this step.
