# Media receipt integrity

Direct and group history reconciliation now validate an own pending message payload before committing history or removing its outbox entry. A matching clientMessageId alone is insufficient. The same validator runs for send acknowledgements.

Checked payloads: image asset; voice asset/duration; video asset/duration/dimensions/audio flag; file asset/name/size/hash; normalized location; quoted message ID. Text validation remains supported, including legacy omitted text type. Recalled/hidden tombstones retain their existing acknowledgement behavior. Incoming messages cannot acknowledge an own pending entry.

Mismatches leave the original queued content available; corrected history confirms it without creating a duplicate. No UI, API, server schema, or installed device changes.

Validation: 148 controller/text/media receipt tests passed, including 84 direct/group history cases covering mismatched, missing, wrong-type, valid, incoming and tombstone receipts. Another 85 existing reply/image/location/history storage/video/file recovery tests passed. Dart analysis of the four changed Dart files passed.

Evidence: build/chat-media-receipt-tests.log and build/chat-media-receipt-regression.log. Repository-call fixtures validate client reconciliation, not a new real-device or production-server acceptance. This change postdates the consolidated d44afcb APK and has not been installed.
