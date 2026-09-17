# Sticker draft and emoji editing batch

The existing single-sticker entry sends through the real image transport. It now first saves an account/conversation-scoped private draft, using the same image draft slot and stable client ID as photo sending. Reopening the photo send flow restores an unfinished selection after process restart. Selecting another sticker explicitly replaces that image draft. Successful queue ownership uses existing idempotent recovery and draft cleanup; the sticker library original is not removed.

Emoji panel backspace follows the text selection/caret rather than deleting the last character. A collapsed caret removes the preceding entire grapheme (including joined emoji); a selection removes the selected range. No visual layout changes.

Phone acceptance and extended edge coverage remain pending: caret at start/middle/end, selected and reversed ranges, invalid selection, joined emoji, sticker source preservation, draft restart, queued send retry and account switch. No phone installation yet. Cloud sticker backend deployment and real A/B sticker acceptance remain separate unfinished items.

Consolidated automated validation: editor cases (caret, selection, joined emoji), draft store, image retention, sticker import/account tests passed. Full batch evidence and limits: [local read batch](2026-09-17-local-read-projection.md).
