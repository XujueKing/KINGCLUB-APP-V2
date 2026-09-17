# Removed outgoing conversation heads

A locally confirmed outgoing preview bridges the interval before the conversation API catches up. When that message is hidden or recalled, its localConfirmed marker must be removed along with its preview; otherwise it overrides an older valid server head indefinitely.

The shared ConversationHistoryRemoval projection now invalidates that marker, including when the preview was already empty. This applies to both in-memory list removal events and the encrypted persisted snapshot.

Validation: 51 history-store and conversation-cache tests passed; Dart analysis passed. Four new database cases cover direct/group hide/recall, reopening the database, accepting an older server preview, and accepting an empty server list afterward.

Not yet verified: device interaction for this batch; remote conversation hiding before this client has received a visibility-floor update remains a separate synchronization gap. No APK installed or backend deployed in this change.
