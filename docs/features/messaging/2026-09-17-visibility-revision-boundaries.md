# Visibility cleanup across newer revisions

The durable visibility journal previously retried forever whenever an authenticated history response had a newer history or membership revision. Boundary cleanup now accepts monotonic newer revisions and uses max(hiddenThrough, joinedSequence) for groups. Regressing or malformed revisions remain rejected.

Cleanup commits against the locally captured epoch/history/membership versions. It does not adopt the new revision or mark all retained rows stale without fetching replacement history. A concurrent foreground revision/membership change causes the transaction guard to reject the obsolete cleanup. Ordinary history synchronization still owns revision adoption and fetching individual recall/deletion tombstones.

Validation: 69 history/cache tests passed; implementation analysis passed. Cases cover direct/group newer revisions, rejecting older revisions, preserving visible group message 2 while removing pre-join message 1, and keeping revision/epoch unchanged during boundary-only cleanup.

This supersedes the matching-revision restriction in the durable visibility journal document. It does not complete account-wide multi-page change discovery, group access-revocation handling, or real-device validation. No APK installed.
