# Messaging batch completion in progress

User direction: implement the remaining batch before consolidated tests and phone installation. Do not alternate tiny changes with device tests. B remains paused. No work in this batch is marked delivered.

## Implemented; consolidated code regression passed, phone acceptance pending

- SecureChatOutbox reference guard serializes history media deletion with pending queue mutations across instances of the same account. The protected reader is lazy: normal commits do not read secure storage. Injected ordinary ChatOutbox implementations retain their original snapshot behavior.
- File/image/video draft discard removes the private file before erasing its metadata locator, so filesystem failure remains retryable.
- Voice cleanup includes the legacy account/file cache alias, subject to remaining references.
- SQLite schema 21 persists encrypted deferred media cleanup locators in the same transaction as history deletion. Locators exclude deleted text, replies, file names, message IDs and authorization grants. Queue removal, subsequent history deletion and store reopening retry collection. Current history and pending references are rechecked before source removal. Filesystem failures retain the locator.

## Remaining batch work and limits

The guard is in-process, not a cross-process transaction. In-process source leases now cover file sending, recorded voice sending, file forwarding and voice forwarding from prepared asset through queue handoff and cache retention. Forwarding leases survive until the flow closes, including multi-recipient use; disposal during active retention releases only after the operation finishes. Image/video client-scoped sources still use their existing permanent deletion fences and need consolidated race coverage. Pending messages are preserved; user-exported files are outside cache cleanup. Message synchronization, attachment recovery and group management remain within the larger batch.

## Consolidated validation scope

Same-account queue mutation/deletion interleaving; lock release after errors; account isolation; no secure-storage read for ordinary commits; failed draft deletion retry; legacy voice alias sharing; schema 20 upgrade; restart recovery; repeated collection; remaining references in another conversation; queue release collection; cleanup failure retains locators; no deleted body in task payload; direct/group clear and recall. The new SQLite/media and reference-guard regressions passed. They cover source preservation across history reopening, remaining references in another conversation, final alias eviction, account-scoped guards, failure release and exclusion of leases from the delivery queue. The complete list above remains the acceptance checklist, not a claim that every item has a dedicated test. No APK for this batch has been installed.

Prepared-source leases are visible only to guarded cleanup snapshots, never returned as queued messages or written to secure storage. Releasing a lease schedules coalesced deferred collection. Consolidated checks must cover close/session change during acquisition/retention, repeated release, forwarding to multiple recipients and queue/history ownership after release. No source lease can survive process death; durable pending/history references and encrypted cleanup locators handle restart.

## Group management and delivery additions

Group invitations and announcements now coalesce notification bursts instead of starting overlapping refreshes. Announcement notifications are scoped to the current group. Group details and announcements revalidate on foreground return; old member-management/transfer/depart confirmations are invalidated by background transitions or membership notifications. Existing UI layout is unchanged.

Background group outbox recovery now opens the same account's persistent history, as direct recovery already did. Leaving the final visible instance of a conversation wakes the recovery worker immediately. Recovery ignores rows claiming a different sender account. Consolidated validation must cover group acknowledgement persistence after worker disposal/restart, duplicate receipts, page-to-worker ownership and permission failures. Existing group management regressions and the new background acknowledgement persistence / announcement burst cases passed. Real-device permission transitions remain pending.

## Executed 2026-09-17

- Initial consolidated run: 130 passed, one new group recovery fixture failed because it omitted the pending membership version. Added the matching version to the fixture; production membership checks were not relaxed.
- Group follow-up: all 36 tests passed, including that recovery case, announcements, owner transfer, departure, member management, capacity and join review.
- File send/session recovery: all 8 tests passed.
- Static analysis of every modified messaging Dart file and associated new/modified tests: no issues.
- The counts above describe separate runs with overlapping group coverage, not a unique combined total. Test transports and secure-storage substitutes do not replace A/B acceptance. No deployment, new phone installation or B operation was performed in this batch.
