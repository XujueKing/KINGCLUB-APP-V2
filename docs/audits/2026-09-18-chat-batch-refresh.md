# Consolidated chat capture, lifecycle and cache build

APK source: 13175cc3321b53de58be0377a38bcd79b2589942, clean detached D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW. Pinned native source remains 579008d18db917bd2e12610a8d1f93bebbef3f51.

ARM64 Profile preview built successfully using scripts/build-chat-preview.ps1, existing HTTPS test API and pinned native source. Gradle 135.9 seconds; native ELF packaging guard passed. No phone installation. No relay, peer-file or LAN options; native binding inclusion is not mainnet acceptance.

Artifact: D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW/build/app/outputs/flutter-apk/app-preview-profile.apk
Size: 167194696 bytes.
SHA256: 7786DCF0558D1FC9E529247690B96A2BCD2F11A8A41A80513C0FAE10CB760205
Build log: preview worktree build/chat-batch-sept18-refresh-build.log.
This replaces the previous 72902aa artifact at the same path.

Includes incoming/outgoing navigator teardown cleanup, native-compatible audio processing flags and video capture targets, missing-track rejection, video retry source identity and background video-cache hashing. UI unchanged; unrelated main-worktree onboarding changes excluded.

Regression: 180 selected chat/conversation/messaging/group/contact/friend/relay/outbox/draft/call/foreground test files. Initial batch: 1037 passed, 10 skipped, 1 failure. Sticker rollback test checked real filesystem cleanup after a fixed 100 ms; changed the test to wait for the add control to re-enable after rollback, bounded at 10 seconds. Existing old-file, journal and new-copy assertions remain. Targeted 8 tests and analysis passed; no production rollback change. A first invocation using absolute paths exceeded Windows batch command length before tests started; reran via Dart's Flutter tool snapshot.

Full rerun: 1038 passed, 10 skipped, 0 failed in 1m43s across the same 180 files. Logs: build/chat-batch-sept18-refresh-tests.log, build/chat-batch-sept18-refresh-final.log, build/sticker-rollback-wait.log and build/sticker-rollback-wait-analyze.log.

Separate app_smoke_test is not part of this selection. Its 15 earlier failures were reproduced against the previous clean baseline (see incoming call route audit); this batch does not claim the entire app test suite passes. Native fixture skips, phone frame timing/audio quality, real group media, pending service deployment and public transport switching remain unverified.
