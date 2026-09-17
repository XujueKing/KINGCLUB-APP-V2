# Incoming-call stale error isolation

After background/resume, the prior request can fail with INTERFACE_DISABLED or INTERFACE_NOT_FOUND. Both inboxes previously handled this error before checking request generation, disabling the newly resumed inbox and dropping its queued follow-up.

Direct/group inboxes now reject stale or closed/background AuthFailure results before changing polling state. A current-generation disabled/missing interface still stops polling until explicitly reactivated.

Evidence: four resumed cases failed before the fix (one request observed instead of the required follow-up). Eight new cases cover both error codes, both inbox types, and current versus resumed generations. The full selected inbox/call-state/group-state/call-history batch passed 39 tests; four-file analysis passed. Logs: build/chat-call-stale-error-before.log and build/chat-call-stale-error-after.log.

No device installation or runtime configuration change. This is client state regression evidence, not new dual-phone calling acceptance.
