# Active file deletion

ChatFileDownloader subscribes to account/group/message deletion notifications.
Matching active downloads are cancelled and joined before cleanup returns.
Completed app-owned temporary directories are associated with message identity
and deleted selectively. Old downloader instances reject another download or
export authorization for the deleted message, even without a resume cache.
Cancellation for deletion does not retain resumable blocks. Exported external
copies are outside this downloader's ownership and remain untouched.

33 downloader/details/cache/cleanup tests passed; analyzer passed. New cases
pause directory acquisition, delete during the pause, and confirm no chunk
request or temporary file remains; another downloads fully, verifies unrelated
account/group deletion leaves it intact, then removes it and denies retry/export.
Tests use transport fixtures, not phone acceptance.

Remaining: shared sent-source cache, legacy transport aliases, remote history
revision removals and outbox/uncached-history ownership. No APK installed here.
