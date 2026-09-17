# Durable conversation visibility checks

History schema 22 adds an encrypted visibility-check journal. A complete server snapshot atomically journals absent previously cached server conversations before replacing the display cache. This includes settled rows, not only temporary outgoing heads. Partial-page probes continue to journal only local-confirmed candidates; page absence itself never deletes history.

After rendering, the existing background reconciler drains pending checks. Failed requests remain across database reopening, even when the list no longer contains the conversation. An authenticated matching history/membership revision supplies hiddenThrough; the existing commit transaction removes history and media references. Successful unchanged boundaries also acknowledge the check. Each replacement queue entry receives a new autoincrement id, so an older response cannot acknowledge a newly queued check. Processing is serialized per store and does not hold a database transaction over network calls.

Security: account-scoped hash indexes, AES-GCM encrypted minimal group/target payload with separate associated data, no media grants/tokens stored. Session disposal stops application of pending responses. Epoch guards continue to reject responses predating local clear.

Validation: 66 history/cache tests pass and analysis passes. New cases cover failure after list removal, reopening and retry without the original list row, no repeat after success, settled and unconfirmed rows, v21 upgrade and encrypted journal contents. The existing old-version migration assertion now expects schema 22.

Remaining: multi-page settled conversations omitted from all pages require a server deletion/change feed rather than inferring deletion from moving offsets; history/membership revision changes require their dedicated synchronization. Real-device multi-session acceptance remains pending. No backend deployment or APK installation.
