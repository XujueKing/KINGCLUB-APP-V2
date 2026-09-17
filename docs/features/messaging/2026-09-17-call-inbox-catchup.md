# Foreground call inbox catch-up

Direct and group invitation inboxes previously discarded notifications arriving during an existing lookup/presentation. A quick background/foreground transition could discard the stale lookup result but then wait for the next five-second poll before finding the incoming call.

Both inboxes now coalesce concurrent refresh requests into one follow-up read when the current operation completes. Closed/background inboxes do not start that read. Existing route ownership and shown-call deduplication remain; discovery does not accept calls or start capture.

Validation: 31 foreground inbox, direct/group call-controller and call-history tests passed. Four new cases cover notification bursts and immediate foreground resume while the first lookup is outstanding, with no timer advancement. Existing background/logout, disabled interface and duplicate-presentation tests also passed. Four-file analysis passed. Initial new widget tests needed explicit timer cleanup before the widget binding completed; corrected fixtures passed. Log: build/chat-call-inbox-refresh.log.

Server source inspection confirmed direct terminal-call records are appended under pair/call locking and historyMessageId idempotency; this was not a new live-server verification. No device installs; new invitation latency behavior remains pending phone acceptance.
