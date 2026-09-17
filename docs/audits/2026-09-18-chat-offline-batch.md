# Consolidated offline queue and access-state batch

Source: ba6ee30445afe9ee666e418645c7ce15dc87dcf8. Clean detached build worktree D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW; native source pinned at 579008d18db917bd2e12610a8d1f93bebbef3f51. Uncommitted onboarding changes excluded.

Built ARM64 Profile preview through scripts/build-chat-preview.ps1 with https://test.wuyexin.cn/kingclub-v2 and the pinned native source. Gradle 155.7 seconds, build exit 0; script's ARM64 ELF packaging validation completed without error. No relay URL, peer-file or LAN options enabled; this artifact does not establish public decentralized routing.

Artifact: D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW/build/app/outputs/flutter-apk/app-preview-profile.apk
Size: 167260232 bytes.
SHA256: 336B7065F960AEC8E98CA194743D50558EB1FE620820FB2E2F5F4E4A30370279
Build log: build/chat-batch-offline-final-build.log in preview worktree.

Replaces the prior 13175cc artifact at this same path. Neither A nor B was installed or operated in this batch; A remains on the previously installed build. Includes off-isolate forwarded-video verification, immediate direct/group send-time denial handling, direct known-permission admission, cached-membership offline group queueing, readmission version protection, and SQLite schema 23 durable group access invalidation. Existing UI retained.

Regression: 180 selected chat/conversation/messaging/group/contact/friend/relay/outbox/draft/call/foreground test files; 1052 passed, 10 skipped, zero failures in 2m06s. Log: main worktree build/chat-batch-offline-final-tests.log. Invoked Flutter snapshot with relative test paths via Python subprocess to avoid the Windows batch command length limit. Prior focused schema/controller suite: 141 passed; eight changed Dart files analyzed without issues.

This is packaged/code-level validation. Skipped native integrations, two-device new offline scenarios, group media packet acceptance, pending backend migrations, and public SuperVM transport switching remain incomplete. Separate app_smoke_test baseline failures remain documented in the preceding batch audit and are not covered by this passing selection.
