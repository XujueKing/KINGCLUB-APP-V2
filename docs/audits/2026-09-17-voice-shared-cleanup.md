# Shared voice asset cleanup

Explicit history clear now evicts voice asset copies after checking encrypted
rows in the other persisted conversations. Shared assets remain available until
the last persisted reference is cleared. Reference inspection is in batches of
50 within the history transaction; it currently scans other history payloads and
should be replaced with an indexed ownership table for very large histories.
Asset eviction deliberately differs from message tombstones: a new authorized
message may reuse the same asset later.

38 history/cleanup/voice-prefetch/playback tests passed. The added test uses real
SQLite encryption and disk audio bytes, places the second reference beyond the
first 50-row batch, verifies preservation, then clears the final conversation and
verifies the file is absent after reopening the media store.

Not full voice deletion acceptance: old transport file-ID aliases, pending
prefetch/playing audio, outbox-only references and media absent from persisted
history still require ownership tracking and deletion propagation. No phone
build was installed for this change.
