# Shared sent-file source cleanup

History clear now collects file asset references remaining in persisted history,
including retained messages in the same conversation during single-message
deletion. Cleanup removes the sender's encrypted source blocks only when no
persisted message still references the asset. ChatSentFileCache removal uses its
existing per-directory operation queue so it follows active retain/read work.
It is ordinary eviction, allowing a later newly authorized message to retain
the asset again. Original picked files and user-exported files are untouched.

50 sent-file/history/cleanup/downloader tests passed; four files passed analyzer.
The added real filesystem test retains source bytes, preserves them with a
remaining reference, releases the final reference, checks the original remains,
and verifies a later retain can work. This is not phone deletion acceptance.

Outstanding: outbox-only references, persisted ownership for history absent on
device, legacy media transport aliases, remote revision removal and full A/B
acceptance. No phone update was installed in this step.
