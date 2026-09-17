# Durable location selection

Persist explicit selected coordinates locally in the existing secure draft
store, scoped to account and direct/group target with a distinct location key.
Reopen the location picker with that selection; selecting never transmits it.
Confirmation uses a stable draft message ID. Queue ownership clears only the
matching draft; reopening an already queued selection does not enqueue again.
Search and fresh selection remain available. Saving failure keeps confirmation
disabled and shows an error, rather than claiming the selection is durable.

No location is obtained automatically. No backend contract changes. Selection
is local and is not synchronized to other devices. Batch checks follow.

## Validation

24 tests passed across location drafts, picker, direct/group queue recovery,
location message rendering/details and secure text draft storage. Added checks
cover reopen identity, account/group isolation, stale cleanup, explicit confirm
and failed durable selection. Existing direct/group restart tests now assert the
caller-provided draft ID survives queueing and retries. Changed Dart analysis
passed. No phone build/install; native location and A/B acceptance pending.
