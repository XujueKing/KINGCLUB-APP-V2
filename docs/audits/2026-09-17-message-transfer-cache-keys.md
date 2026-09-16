# Message-scoped voice/video transfer copies

New voice downloads (playback and inbox prefetch) and video/poster downloads use
account/group/message/slot cache identities. Explicit cleanup now removes these
transfer copies as well as retained message/asset copies, with durable deletion
tombstones. Video permission cleanup and native voice decoder-failure cleanup
also evict the new identities. Images already download directly to message keys.

53 media/voice/video/history tests passed; analyzer passed for five files.
New real filesystem tests remove audio/video transfer copies, reopen the cache,
and verify late imports remain rejected. Eight prefetch/inbox tests also passed
after asserting the actual requested transfer identity.

Legacy file-ID-keyed voice/video blobs remain to be migrated or reclaimed;
their hashed filenames do not encode message ownership. This change covers new
download identities, not a claim that existing phone storage is fully cleaned.
No APK was installed during this step.
