# Chat visibility batch: build and regression

Source: 16867c5fbd5c1721397bf7578d0ffe0ce6100620, clean detached KINGCLUB-VOICE-PREVIEW checkout. Existing unrelated onboarding and NovoRUDP working-tree edits were excluded.

## Android build

scripts/build-chat-preview.ps1 with API https://test.wuyexin.cn/kingclub-v2 and pinned native source D:/WEB3_AI/SUPERVM-KINGCLUB-PINNED completed successfully. ARM64 preview Profile APK, Gradle 228.6 seconds, reported 159.4 MB. Native packaging checks in the script passed. No LAN/relay/peer-file runtime configuration was supplied: this is a compile artifact, not proof of adaptive transport or a replacement for the configured LAN acceptance build. No device installation.

APK: D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW/build/app/outputs/flutter-apk/app-preview-profile.apk
SHA256: 60F2502D5E63BD6754E22B5E9083BADAFEC8BF106FFB204751E275B1996B92C9
Build log: build/chat-visibility-batch-build.log in that checkout.

## Consolidated tests

Selected test files matching chat/conversation/messaging/group/contact/friend/relay/outbox/draft. First run: 817 passed, 10 skipped, 11 failed (build/chat-batch-full-tests.log). This was not a green full-suite run.

Nine failures were resolved and checked with targeted reruns:
- Five resume tests still expected completed encrypted blocks to disappear. They now verify durable blocks, downloader recreation, byte-exact offline restore without further grants or block requests, and plaintext temporary cleanup. The revoked-grant case still requires cleanup.
- Video deletion expected a retry button; now verifies removed-content state with no retry action and no playback/regrant.
- Contact migration asserted obsolete schema 20; updated to schema 22 while retaining its existing-data checks.
- The real 65 MiB encryption/decryption case exceeded its 30-second test timeout during concurrent build. It passes with an explicit two-minute integration-test timeout. This does not constitute a mobile performance acceptance result.
- Back arrow uses the global glyph size and a one-pixel alignment tolerance (header bottom divider produces a half-pixel center difference).

Four corrected test files ran 25 passed / 1 failed before the final video-test correction. The full video file then passed 7 tests and the back-control check passed 1. All five changed test files passed analysis. Unchanged passing tests were not rerun merely to manufacture a new aggregate count.

## Still unresolved

Two legacy visual checks: attachment-panel golden differs from current two-row paginated panel; gift-panel test references a removed dedicated composer gift button. No golden files were overwritten, no production UI changed to satisfy old snapshots. They require current-flow visual baseline review. Ten skipped checks are not delivery evidence.

Phone acceptance, multi-page server change discovery, full end-to-end encryption, public-chain switching, complete financial features and other open items in the delivery matrix remain incomplete.
