# Paginated terminal visibility

Reproduced in both direct and group controllers: 120 cached records, latest 50 initially loaded, next local page loads 21..70, but a stale server page returns 1..70. Recalled record 1 and hidden record 2 exist on disk outside the loaded range. The store preserves their terminal state, while the controller previously rendered the raw response and restored the old content.

ChatHistoryStore.commit now optionally publishes the effective committed messages after successful persistence. Both controllers use these canonical messages for page merging and individual acknowledgements. No second database read, schema change or UI layout change. Failed commits do not publish rows.

Evidence: both focused reproduction tests failed before the change (expected recalled, actual null). After the change, 149 direct/group history, deletion-event and text/media receipt tests passed; analysis of all five changed Dart files passed. Logs: build/chat-old-tombstone-baseline.log and build/chat-old-tombstone-fixed.log. This source fix postdates the 758ab7d APK and has not been installed or tested on phones.
