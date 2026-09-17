# Confirmed conversation head reconciliation

A confirmed outgoing head is a temporary bridge, not a permanent override of the server list. Capture encrypted cached heads before requesting conversations. For a successful complete first-page response (hasMore=false), retire markers no newer than that captured sequence. The server can then omit a remotely hidden conversation or return an older visible head. Confirmations received during the request remain protected, including when saving the snapshot transactionally.

Partial pages, pagination responses, absent hasMore, and network failures do not infer deletion. This change does not delete message history or media merely because a list row is absent; history visibility-floor synchronization remains responsible for that cleanup.

Validation: 53 history-store/conversation-cache tests passed; analysis of the two implementation files passed. New direct/group cases exercise complete omission, concurrent outgoing confirmation, database reopening, and replacement with an older server head. Existing partial snapshot bridge tests remain passing.

Remaining: multi-page authoritative reconciliation, real-device multi-session hide/clear acceptance, and history cleanup when a hidden conversation is never reopened. No device installation or backend deployment performed.
