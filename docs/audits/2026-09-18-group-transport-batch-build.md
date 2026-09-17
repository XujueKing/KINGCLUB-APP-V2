# Consolidated group transport preview

Source cfb45a7481420ffeb783d8509235538aa97eb791, clean detached
KINGCLUB-VOICE-PREVIEW worktree; unrelated onboarding and commerce changes
excluded. Native source remains pinned at 579008d18db917bd2e12610a8d1f93bebbef3f51.

Android ARM64 Profile preview generated with the established service URL and
native device binding. Relay/LAN/peer-file/group-file options remain disabled.
No production interface deployment and no A/B device operation.
Gradle reports build success in 348.7 seconds. The outer PowerShell invocation
returned 1 while redirecting native stderr (the logged error record contains
Cargo's successful release completion message). Do not describe this wrapper
exit as clean. The APK was independently checked: ZIP CRC integrity passes,
and its packaged native library is ARM64 ELF, 1014832 bytes.

Artifact: D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW/build/app/outputs/flutter-apk/app-preview-profile.apk
Size: 167260232 bytes.
SHA256: 07FD4996588C61843C9E92FEA2D89D2CC0404C8A634FD3DA48D120CBCCB856FE
This replaces the prior artifact at that path and has not been installed.
Build log: preview build/chat-group-batch-build.log.

Regression: 201 selected chat/conversation/messaging/group/contact/friend/relay/
outbox/draft/call/foreground/NovoRUDP/peer-file test files; 1095 passed, 77 skipped,
zero failed in 5m16s. Selection is build/chat-group-batch-selection.json;
log is build/chat-group-batch-tests.log in the main worktree. It is not an
all-application run. Native/server-gated skips remain explicit; separate real
native + encrypted HTTP + LAN tests are recorded in the group-native-HTTP audit.
The broad suite and APK build ran concurrently, so these times are not an
isolated build-speed benchmark. Phone UI/performance and public NAT remain pending.
