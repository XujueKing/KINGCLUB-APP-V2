# A device consolidated preview acceptance

Installed the consolidated 13175cc ARM64 Profile preview APK on A via adb install -r; package manager returned Success. Artifact SHA256 7786DCF0558D1FC9E529247690B96A2BCD2F11A8A41A80513C0FAE10CB760205. The startup script confirmed the preview activity remained foreground. Account data was not cleared. B was not operated or updated.

Observed existing conversation list and original direct conversation after update, including participant avatars, timestamps and existing message rows. No outgoing message, invitation or call was generated. Screenshots remain local because they include member data.

Captured three keyboard open/back cycles in that conversation through the current process Dart VM timeline. Restored timeline stream flags and removed the temporary adb forward afterward. 228 paired UI Frame spans: p50 4.402 ms, p95 7.820 ms, max 10.868 ms, zero above 16.67 ms. 228 GPURasterizer::Draw spans: p50 5.779 ms, p95 7.610 ms, max 14.849 ms, zero above 16.67 ms. Final screenshot confirmed keyboard closed and original history remained visible.

These are individual UI/raster execution spans, not end-to-end input latency or presentation cadence. No claim of universal smoothness, 120 Hz acceptance, audio processing quality or send/receive animation acceptance. Latest group call and transport scenarios remain pending. Raw local evidence: build/chat-keyboard-sept18-timeline.json, build/chat-keyboard-sept18-summary.json and build/a-batch-*.png. Do not publish raw member screenshots or VM endpoint credentials.

## Offline process restart

On the same installed 13175cc build, disabled A Wi-Fi and mobile data (both originally enabled), force-stopped and relaunched the preview without clearing data. The app showed its offline banner. Opened conversation list, contacts and an existing direct conversation: persisted rows, contact names, participant avatars, message timestamps and existing history were visible. This was a new process, not simply navigating to an already-mounted page.

Opened the already-cached 8-second synthetic video from that history. The offline player displayed changing test frames, progressed from approximately 0.9 seconds to 7.93 seconds, then showed a full progress bar and play control at completion. Audio was not independently listened to during this run. Returned to the conversation and restored Wi-Fi and mobile data; both settings read 1 afterward. No messages were sent, no records deleted, no B operations.

Local evidence: build/a-offline-restart.png, a-offline-list.png, a-offline-contacts.png, a-offline-history.png, a-offline-video.png and a-offline-video-end.png. Do not publish member-bearing screenshots. This establishes restoration and playback for the existing sample only, not never-downloaded attachments, all codecs, large-history latency or offline group authorization changes.
