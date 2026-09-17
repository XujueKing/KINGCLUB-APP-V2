# Draft-only conversations: work in progress

Confirmed gap: ConversationDraftPreview decorates existing conversation rows,
but ConversationsPage builds those rows from server/history conversation lists.
A first unsent text draft without a conversation row is therefore not reachable
from the chat list. Opening the original peer still restores its text draft.

Added account-scoped text-draft enumeration and account change notifications.
Enumeration uses each draft's normal serialized read/quote-redaction path, rejects
session changes, excludes other accounts and location drafts, skips malformed
individual drafts, and omits deleted/empty values. Seven enumeration and existing
text-draft tests passed.

Not delivered yet: connect draft-only rows to ConversationsPage, retain display
names, deduplicate actual conversations, define explicit draft removal, and verify
cold restart, account switch, send completion and list refresh. The new API alone
is not evidence that users can see draft-only rows. No device build/install.
