# Hidden confirmed-head boundaries

Missing local-confirmed heads in a conversation page are checked against the authenticated direct/group history endpoint (limit 1). Only an increased hiddenThrough boundary with matching persisted history revision and, for groups, matching membership revision can remove retained history. Cleanup uses the existing transactional commit path, including media ownership cleanup and draft redaction. Epoch checks reject responses predating a local clear.

The checks run after the list is rendered and saved. No artificial loading or pagination wait is added. Failed/malformed/offline responses and account/session disposal do not imply deletion. A paginated absence alone never authorizes cleanup.

Validation: 63 history-store/cache tests passed, including ten new direct/group cases for hidden, visible, offline, changed revision and inactive session. Dart analysis passed. Conversation-cache widget tests were rerun after moving checks behind rendering.

Scope limit: only temporary local-confirmed heads missing from the returned page are probed. This is not a complete account-wide deletion journal: already settled hidden conversations, changed history/membership revisions and removal recovery after offline failures still need comprehensive synchronization. Device validation is pending; no APK installed or service deployed.
