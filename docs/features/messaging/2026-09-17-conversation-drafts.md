# Conversation draft previews

Show locally persisted unsent text in the existing conversation preview line,
with a draft prefix. Keep the existing row height, typography, sorting and unread
counts. Read only the displayed conversation's secure draft; do not enumerate
secure storage or wait for drafts before displaying the list. Notify matching
account/conversation widgets after draft commits and queue-owned cleanup.
Ignore stale reads after navigation/account changes and immediately clear draft
content on session changes. No cloud draft synchronization is implied.

Acceptance: persisted restore, edited/removed draft events, outgoing cleanup
cannot delete a newer draft, group/direct and account isolation, stale load
suppression. Real-device acceptance remains pending until the consolidated build.

## Validation

Consolidated run: 19 tests passed across draft preview, durable text drafts,
conversation cache, refresh ordering, pagination and relay unread widgets.
Static analysis of all changed Dart files passed. Covers cold draft restore,
editing, removal by matching draft ID, direct/group and account isolation,
session invalidation, and a late old-account open. No phone installation.

Scope: previews apply to existing conversation rows. Draft-only conversations
that have no server or local history row are not yet surfaced by this batch.
