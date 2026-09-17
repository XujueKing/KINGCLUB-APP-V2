# Draft-only conversations

Previously ConversationDraftPreview only decorated existing server/history rows,
so first unsent text drafts were absent from the chat list. The list now reads
account-scoped text drafts and shows missing peer/group conversations with the
existing row layout and a draft preview. These rows carry no unread count, are
not written as server conversation records, and do not change server pagination.
Existing server/history rows take precedence and prevent duplicates.

New drafts retain the conversation display name through quote redaction. Legacy
drafts without names use a generic friend/group label rather than internal IDs.
A draft-only row opens the normal conversation; long press offers explicit draft
deletion guarded by the displayed draft ID, so replacement text is preserved.
Account changes invalidate late reads and clear current draft-only rows.

Enumeration uses serialized draft reads and quote redaction, excludes other
accounts and location drafts, and skips malformed individual draft records.
13 draft enumeration/store/list/action tests passed; analysis of the four changed
implementation/test files passed. Widget evidence covers page recreation, named
preview, deletion, duplicate suppression and session invalidation. Existing store
tests cover replacement-ID cleanup guards. Cold-process device acceptance and
real sending from the newly surfaced row remain pending; no phone installation.
