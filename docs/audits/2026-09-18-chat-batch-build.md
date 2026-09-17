# Chat batch Android build and regression

Source APK: 72902aa7be6636f0ca81a72c9cb9da38dc6699ae, clean detached D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW. Pinned native source: 579008d18db917bd2e12610a8d1f93bebbef3f51.

Build: scripts/build-chat-preview.ps1 with the existing HTTPS test API and pinned NovoRUDP source. ARM64 Profile preview; Gradle 204.0 seconds while regression ran concurrently. Script exited 0 and packaged native ELF check passed. Plugin Kotlin migration warnings were nonfatal.

Artifact: D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW/build/app/outputs/flutter-apk/app-preview-profile.apk
Size: 167194696 bytes (159.4 MB).
SHA256: 841B8E1E8A1B6E8C4091B4F8F8BB938542EE48208B1943E69638845AEB56167D
Build log: build/chat-batch-sept18-build.log in preview worktree.

Includes all committed client fixes through group-call record persistence/rendering/callback selection, incoming-call refresh/stale-error handling, hidden/cleared-history receipt reconciliation and pagination boundary fixes. Main-worktree uncommitted onboarding edits were excluded. No source UI changes were made during this build.

No relay endpoint/trust certificate, LAN or peer-file flags were supplied. Native device binding is compiled in; runtime remains service-backed. This does not prove public-mainnet, LAN-mobile or automatic public-network transport switching. Server group-record fields depend on ccsop cd80ea9 and migration 123, which have isolated integration evidence e297f0e but are not deployed to the app endpoint. No phones were installed or operated.

Regression selection: 179 files matching (chat|conversation|messaging|group|contact|friend|relay|outbox|draft|call|foreground).*_test.dart. First run: 1025 passed, 10 skipped, one failure in sticker capacity import. The test read the real filesystem after a fixed 200 ms and saw the old journal despite the copy starting. Changed the test to await durable journal replacement with a 10-second bound; no production behavior/capacity assertion changed. Targeted 8 import tests passed. Full rerun: 1026 passed, 10 skipped, 0 failed across the same 179 files; static analysis of the modified test passed. Skipped native runtime cases require their explicit library/relay fixtures and are not counted as passed; logs build/chat-batch-sept18.log and build/chat-batch-sept18-final.log.

The APK replaces the earlier 758ab7d artifact at the same path. Historical audit hashes are retained; they do not describe the current file.
