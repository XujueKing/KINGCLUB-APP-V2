# Deletion entry routing

Controller history resets also serve refresh/revision recovery. They now default
to preserving media; treating every reset as an explicit clear would permanently
tombstone attachments belonging to messages that remain visible. Explicit page
clear passes clearMedia=true. Direct/group single-message hide and recall pass
only their acknowledged message ID to media cleanup. Other attachments remain.

The history store still invalidates the conversation's row cache and advances its
epoch during these resets; controllers reload authoritative history. Selected
media cleanup checks voice references both within and outside the conversation.

Conversation-list hide/delete now clears direct persisted history even without
NovoRUDP enabled, and also clears group persisted history. Server success remains
required before local clear. Existing nearby-hide semantics are retained.

67 store/controller/hide/group-list/relay-list tests passed. Seven changed files
passed analyzer. A real disk test proves refresh preserves media and selected
deletion removes one message's image while keeping the other. No phone install
or whole deletion acceptance yet. Remote revision deletion, missing local rows,
transport aliases, shared sent-file source and outbox ownership remain pending.
