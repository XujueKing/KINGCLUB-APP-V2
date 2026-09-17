# Consolidated Android chat build — 2026-09-17

Source: d44afcb6e80cc84accaff7114c813318ede58ba8, clean detached D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW. Unrelated working changes in the primary app checkout were excluded. Build script completed successfully and the checkout remained clean.

Command: scripts/build-chat-preview.ps1 -ApiBaseUrl https://test.wuyexin.cn/kingclub-v2 -NovoRudpSourceRoot D:/WEB3_AI/SUPERVM-KINGCLUB-PINNED

- Mode: Profile, preview flavor, Android ARM64. Application ID com.lingmei.kingclub.v2preview.
- Gradle: 96.2 seconds; APK 167194696 bytes (reported 159.4 MB).
- Native source pinned to 579008d18db917bd2e12610a8d1f93bebbef3f51. Native release compilation and packaged ARM64 ELF/header validation passed.
- APK: D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW/build/app/outputs/flutter-apk/app-preview-profile.apk
- SHA256: BE6819840BD233E11C3E274B2D57549CA2F46F7E0A62B26F7269040B076D891B
- Local build log: D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW/build/chat-consolidated-build.log

This supersedes the older 16867c5 build at the same APK path. Includes multi-interface LAN receive code, abandoned peer-file cancellation, text receipt/history validation, and earlier consolidated persistence/UI changes. Regression evidence: 856 passed, 10 skipped in the preceding selected batch, documented separately.

No RelayUrl, RelayPeer, relay certificate, EnableLan or EnablePeerFiles flags were supplied. Native device binding is compiled in, but this artifact is a service-backed preview, not a configured LAN/mainnet acceptance build. No phone installation, fresh dual-device acceptance or deployment. No claim of public-mainnet delivery, complete E2EE, or completion of all chat features.
