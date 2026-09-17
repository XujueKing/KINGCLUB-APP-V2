# Search/context group access revocation — 2026-09-17

GroupChatController already clears saved history on CHAT_GROUP_ACCESS_DENIED. Independent search and context pages previously only cleared their visible results. Both now apply the same definitive group-access rejection to the account-scoped saved group history. This closes the independent-route gap after local-first previews were introduced.

The helper acts only on CHAT_GROUP_ACCESS_DENIED with a nonempty group ID, verifies the opened store account, and clears that group with the same deleteMedia:false policy used by group access revocation. It does not erase unrelated conversations, treat network failures/muting/generic errors as revocation, or claim to remove every retained media byte. Search/context stop accepting the current local preview as soon as the remote request fails. Context now explicitly closes that preview window in finally as well.

Validation: 37 tests passed across encrypted storage revocation and search/context lifecycle flows. SQLite tests reopen the store to verify persistence and preservation of unrelated groups/direct history; direct routes never open group storage. Static analysis passed. No phone install or online deployment. Disk-cleanup failure keeps the error screen but is not represented as successful durable cleanup; existing account/session guards remain in force.
