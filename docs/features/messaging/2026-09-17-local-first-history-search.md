# Local-first history search — 2026-09-17

Previously the search page waited for a NETWORK_ERROR from the remote request before searching saved records. A slow/offline network therefore delayed results that were already available locally.

The first search now starts encrypted local lookup alongside the server request. Valid cached results appear while the request is pending. Remote success replaces the preview and owns subsequent pagination. NETWORK_ERROR reuses the pending/completed local lookup and continues local pagination. Explicit denial or another remote failure clears the preview. A finished remote request cancels default local scanning; late local results cannot overwrite server results or reappear after denial, query invalidation, deletion or logout. Shared result parsing preserves ordering, visibility filters and cursor validation.

Added an account-scoped local lookup injection for controlled widget tests. Production callers still use the encrypted ChatHistoryStore and its activity/cancellation checks; no separate plaintext index was introduced. Existing page visuals and 30-result paging remain unchanged.

Validation: 16 tests passed across local-first widget scenarios, existing history-search page behavior, and encrypted search cancellation/concurrent writes; both changed Dart files passed analysis. Covers slow server success, offline fallback without duplicate local scan, local next page, denial, late cache after success/denial, logout, existing scope/deletion and page boundaries. No APK rebuild or phone installation; subjective phone responsiveness remains pending.
