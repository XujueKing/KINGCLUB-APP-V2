# Terminal history visibility

A delayed history snapshot could replace recalled content in the controller and replace both recalled/hidden tombstones in encrypted SQLite. Preserve terminal visibility at both layers: hidden wins over all subsequent content; recalled wins over ordinary content and may still become hidden.

SQLite checks the saved payload inside the write transaction after epoch/version validation. The effective tombstone is also used for outgoing-head and nearby reconciliation, rather than only skipping a row update. No schema change. Controller hidden-message memory now also retains recalled state when a stale snapshot arrives.

Validation: 191 history/deletion/reply/media cleanup/text/media receipt tests passed. A further run passed 27 controller receipt and 10,000 encrypted-message search/concurrent-write tests. The final four deletion-event cases additionally close/reopen the encrypted database before replaying original content and verify that a hidden message also resists replay; all passed. Static analysis of the five changed Dart files passed before the final test-only expansion.

Logs: build/chat-tombstone-tests.log, build/chat-tombstone-scale.log, build/chat-tombstone-reopen.log. These are client regressions with real SQLite and fixture repository responses, not dual-phone acceptance. No device installation or production deployment in this node.
