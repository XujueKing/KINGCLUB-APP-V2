# Chat media deletion — partial implementation

Explicit history clear now removes image/video message-local copies (including
thumbnail/poster and own sent copies) before deleting their encrypted message
metadata. Records are read in batches of 50 inside the clear transaction. A
filesystem failure propagates and preserves the database metadata for retry.
Other accounts and avatar keys are untouched.

Validation: 12 history/cleanup tests passed; analyzer passed for three files.
The cleanup test writes real files and reopens the store to check removal and
account isolation. No phone build or full deletion acceptance yet.

Remaining: voice and file stores; transport-cache aliases; media not represented
in persisted history; durable cleanup retry; prevention of late media writes;
server revision/individual deletion paths and all UI entry points. This change
does not satisfy complete attachment deletion until these are implemented and
verified. User-exported gallery/download originals must remain separate.

## Late-write fencing

Message image/video deletion now uses a durable hashed tombstone, distinct from
ordinary decoder-failure eviction. Reads, downloads and imports reject deleted
keys, including after reopening the store. Pending writes are checked before
and after publication, and deletion waits for the existing pending operation
before removing its file. Other media keys remain usable.

27 history/media/cleanup tests passed, including a held HTTP response released
after deletion begins, absence of final/partial files, and rejection of a new
import by a reopened store. Analyzer passed. This addresses late writes only
for the message-owned keys already wired here; voice, file and transport aliases
still need ownership-aware cleanup. No phone installation in this step.

## File download blocks

Explicit history clear now reconstructs the exact account/group/message/asset/
size/hash/name identity used by ChatFileDownloader and permanently removes its
encrypted download blocks. Tombstones survive cache pruning and reopening.
Reads reject deleted identities; writes check before and after publication.
Downloader checks deletion before requesting a grant, between blocks, and before
returning either server or peer results. Exported user files are not targeted.

48 cache/cleanup/downloader/sent-file/history tests passed; six files passed
analyzer. New tests cover exact identity routing, reopened cache refusal, other
identity preservation, and refusal to restart a deleted download without making
a grant request. Network tests use fixtures; no phone deletion acceptance yet.

Still outstanding: shared sent-file source cache, already-returned temporary
files/viewers, absent resume-cache case, voice and transport aliases, revision
and individual-delete paths, and media never inserted into local history.
