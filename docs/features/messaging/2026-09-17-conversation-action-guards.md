# Conversation action consistency

Scope: existing direct/group conversation read, pin, hide and block controls.
Serialize actions per account-bound repository and conversation while a mutation
and its refresh are running. Ignore old row/menu callbacks after account rebind;
resolve current row settings at action time rather than replaying a stale pin
value. Suppress old-account response notices and follow-up local cleanup.
No UI layout changes, new network endpoints, or permission changes.

Validation: repeated actions issue one mutation; menus opened before session
invalidation cannot mutate; direct and group keys remain distinct. Batch tests
and analysis follow implementation. Real-device acceptance remains pending.

## Validation

Consolidated run: 14 tests passed across action guards, menu actions, refresh
ordering, relay unread, persistent list cache and group conversation lists.
The new widget cases exercise duplicate pin requests for both direct and group
rows, a stale row callback after a successful pin, and session invalidation while
the action menu is open. Changed Dart files pass static analysis.
No new phone build/install or real-device acceptance claimed.
