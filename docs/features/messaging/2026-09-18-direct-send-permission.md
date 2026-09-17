# Known direct-message denial before queue ownership

Direct history already returns authoritative sendPermission, but new-send methods did not consult it. Reject new text/image/file/location/voice/video queue ownership when allowed is explicitly false. Unknown permission remains compatible with offline queueing; the server is authoritative. Keep retry of an existing message separate so an earlier successful send can reconcile its idempotent receipt even when a new invitation is forbidden. No UI redesign, automatic relationship change or draft clearing.

Validation: 171 tests passed across direct controller/history, five media queue suites and text/media receipts. Four new denial cases verify no queue ownership/callback/API send, then successful send after authoritative permission recovery. Static analysis passed. Existing retry path is unchanged and remains eligible to reconcile earlier accepted IDs. Logs: build/direct-permission-final.log and build/direct-permission-analyze.log. Not packaged or installed; real blocking/reply-limit phone verification remains pending.

## Send-time denial follow-up

Adopt current-generation server CHAT_BLOCKED/CHAT_AWAITING_REPLY/CHAT_FOLLOW_REQUIRED/CHAT_INACTIVE/CHAT_SELF responses as explicit new-send denial. Do not erase readable history or the failed outgoing item. Do not classify these as transport failure or attempt service-failure relay fallback. Existing message receipt reconciliation remains available; unrelated errors do not invent a relationship change. Follow-up: 144 controller/text/media receipt tests passed, including five new rejection cases and old-ID reconciliation. Static analysis passed. Logs build/direct-send-denial.log and build/direct-send-denial-analyze.log. No new APK or phone installation.
