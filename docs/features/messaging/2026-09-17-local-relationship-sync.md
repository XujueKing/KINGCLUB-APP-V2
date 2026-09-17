# Local relationship mutation notifications

After successful request submission/resolution or relationship mutation, publish
an account-scoped local invalidation. Contacts reload actual server contacts and
pending requests, conversation rows reload actual data, and an open direct chat
refreshes permission/profile state. No speculative friendship is manufactured.
Keep realtime notifications for remote operations. Coalesce friend-request list
refreshes so local and websocket notifications do not fan out repeated paging.
Keep existing rows visible during refresh; clear them on session invalidation.

Batch validation follows implementation; missed remote websocket delivery still
requires reconnect/foreground synchronization. No phone installation yet.

## Validation

Consolidated eight-file regression: 42 tests passed. The expanded local event
suite subsequently passed 3 cases (2 overlap the consolidated run). Added widget
coverage proves accepting a request updates an already mounted contact list and
its pending badge without any websocket event; request bursts trigger one active
read plus one follow-up. Failed mutations emit no local success event and other
accounts do not receive it. Changed Dart analysis passed. Real A/B acceptance is
still pending and the opposite device continues to depend on remote sync.
