# First offline send remains reachable

ConversationsPage now observes the account secure outbox and displays missing
single/group conversations whose first message is still queued. Local queue reads
run before the background network list refresh. The latest queued message supplies
the preview; media use type labels. Rows have zero unread count and are not included
in server pagination or persisted as fabricated server conversation records.
Existing server/history rows take precedence; draft-only rows do not duplicate a
pending conversation. Pending-only rows open the normal controller, which restores
the queue, and do not offer unrelated server pin/delete actions. Account changes
clear rows and invalidate in-flight reads.

Limitations: missing local name metadata uses friend/group labels. This does not
solve a gap after queue acknowledgement if the next server snapshot still omits
the conversation, or provide a permanent local index of acknowledged conversations.
The main chat controller remains responsible for delivery, retry and permissions.

Eight pending projection, draft/list widget and existing conversation-action tests
passed. Five-file analysis passed. Widget verification covers an initially queued
first direct message, removal, and a newly queued group message. No phone install
or offline-device acceptance was performed.

Follow-up: the acknowledgement-to-list gap is now addressed in code by
[transactional confirmed summaries](2026-09-17-confirmed-conversation-bridge.md);
its device acceptance is still pending.
