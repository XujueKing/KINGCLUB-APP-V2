# Local read display and sticker editing batch

The durable read outbox already retries server acknowledgements. Conversation
lists now also project pending local read watermarks onto server and cold-cache
rows. Only a fully viewed server head clears its server unread count; unknown
heads and newer messages remain unchanged. Nearby relay unread counts remain
independent. Direct and group identifiers and account stores stay isolated.
New local read intents notify the list immediately, without waiting for network
success. Repeating the same watermark does not create a refresh loop. A list
request retains its initial watermark snapshot if an acknowledgement removes
that pending intent while the request is in flight.

This is a display projection, not a server acknowledgement or a permission
change. Partial-head unread counts remain conservative until reconciliation;
sequence differences cannot count incoming messages accurately.

This batch also includes persistent selected-sticker drafts and cursor-aware
emoji deletion. Validation is consolidated below after implementation; no new
phone installation or real-device acceptance is claimed yet.

## Consolidated validation

- 12 read/list/editor/send-recovery test files: 45 passed.
- Final relay/pagination/refresh subset after race guard adjustment: 6 passed
  (overlaps the 45; not additional distinct coverage).
- Draft store, image retention, sticker import and account tests: 15 passed.
- Changed production files and tests: Dart analysis passed.
- Existing offline badge expectation updated to immediate local read behavior.
  Two filesystem widget checks now await the observable result with a 5-second
  deadline instead of assuming encrypted/native I/O finishes within 100ms.
- No phone build/install in this batch. Sticker end-to-end restart/real send and
  A/B offline badge acceptance remain pending. No server deployment included.
