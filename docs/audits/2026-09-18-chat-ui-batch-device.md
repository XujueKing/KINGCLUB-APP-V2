# Conversation UI and pending preview batch

Source f68744b01c014c77d63678a643a790de42941488, clean detached
KINGCLUB-VOICE-PREVIEW worktree. Native source pinned at
579008d18db917bd2e12610a8d1f93bebbef3f51. Unrelated onboarding work excluded.

ARM64 Profile preview build passed in 78.6 seconds with native ELF guard.
API https://test.wuyexin.cn/kingclub-v2; relay/LAN/peer-file flags not enabled.
Artifact build/app/outputs/flutter-apk/app-preview-profile.apk in preview worktree:
167260232 bytes; SHA256
17FC95B73FDB92A291C75BF1E12740FB0A9D24C69870D1CECEA74F5F1B62F161.
Build log: build/chat-ui-batch-build.log in preview worktree.

Regression: 81 tests across 11 files passed (main worktree
build/chat-ui-batch-tests.log); another 11 tests across the draft-only list,
conversation cache and refresh-order suites passed. Total 92, no failures.
This is a focused batch, not another full application run.

Installed on A (462606d8) with adb install -r: Success. Startup foreground
verified; retained conversations, avatars and group history observed. B untouched.

A test group KINGCLUB-AB-0915-OK:
- Opened attachment panel; first Android Back closed only the panel, second
  returned to the conversation list without leaving the app.
- Disabled Wi-Fi and mobile data (original values both 1). Sent one authorized
  test marker KINGCLUB-PENDING-PREVIEW-0918-0616. Bubble showed waiting for network.
- Android Back dismissed keyboard, then returned to list. Group preview showed
  the new marker with pending prefix, retaining the group identity and ordering.
- Force-stopped and restarted while offline. The list restored the same pending
  preview, with cached contact names/avatars intact.
- Restored Wi-Fi/mobile settings and verified both 1.

Local screenshots build/a-ui-batch-*.png. Route transition captures may contain
an intermediate frame; they are not frame-pacing benchmarks. B receipt, public
route switching and every group-file source scenario are not established here.

On reconnect, list pending prefix disappeared automatically and timestamp became
06:17. Reopening group showed one marker without waiting status. No retry tap.
Own-avatar tap then exposed a genuine backend mismatch: profile page showed
self-message rejection instead of identity. This batch does not count own-avatar
profile as delivered; follow-up changes use authenticated own snapshot 501.

## Own-profile correction artifact

Source 6d5d211571ae027e9a521a887cb02f9a1ddc3155 built successfully, Gradle
68.7 seconds, ARM64 ELF guard passed. Same build configuration and artifact path;
167260232 bytes, SHA256
4EF51F21585F3D0F91F084276DF6757937F0787B6B9F107884EB8F745AE62723.
This replaces the first artifact above. Five profile/avatar tests passed again
and static analysis passed. adb install -r returned Success on A.

After installation/start, A unexpectedly displayed the AA reservation page,
not the expected chat/home flow. No taps were issued on that page. Device
operations paused to avoid interfering with another operator; own-profile actual
rendering verification remains pending. This is not counted as successful
own-profile device acceptance. Build log: preview build/chat-own-profile-build.log.
