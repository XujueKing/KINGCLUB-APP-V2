# Local history search at 10000 messages — 2026-09-17

Added a reproducible desktop integration case using the real encrypted ChatHistoryStore and SQLite FFI database, with 10000 committed messages. Only the oldest 65 match the target query, forcing a meaningful scan through the recent nonmatching history. This complements cancellation tests; it does not time a query that is immediately cancelled.

Observed single run on this development computer:
- First 30-result search: 722 ms.
- New message commit while search was still running: 19 ms, successful before the scan completed.
- Exact chronological result pages: 36–65, 6–35, then 1–5, with correct hasMore states and no overlap.
- Dense recent query: returned 30 results and stopped early (36 cancellation/activity checks rather than scanning 10000 messages).

The test uses real encryption/decryption and database commits, synthetic contents, bounded result pages, and temporary-directory cleanup. Timing is printed as evidence, not an arbitrary cross-machine pass/fail threshold. One test and static analysis passed. No production search algorithm or UI was changed: these measurements did not justify speculative optimization.

Limits: desktop Flutter test runner, not Android Profile/release, not a cold OS disk-cache benchmark and not a memory/frames/energy measurement. Stored history can still take proportional scan time for sparse/absent matches because no plaintext search index is persisted. Device-scale latency remains open. Log: build/chat-search-scale.log; test: test/chat_history_search_scale_test.dart.
