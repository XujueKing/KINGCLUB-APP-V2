# Chat history batch Android build

- Source: 758ab7d23d74c9c3a9b2c7c5dfc2c041cc05462f, clean detached worktree D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW.
- Command: scripts/build-chat-preview.ps1 -ApiBaseUrl https://test.wuyexin.cn/kingclub-v2 -NovoRudpSourceRoot D:/WEB3_AI/SUPERVM-KINGCLUB-PINNED.
- Pinned native source: 579008d18db917bd2e12610a8d1f93bebbef3f51.
- Result: ARM64 Android Profile preview build succeeded; Gradle 87.3 seconds; packaged native ELF architecture check passed.
- APK: D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW/build/app/outputs/flutter-apk/app-preview-profile.apk.
- Size: 167194696 bytes (Flutter reports 159.4 MB).
- SHA256: 29AE8FF27EB15F5975051C14F8125465B655188B754CE6D1FC7D80E6EF0C32EE.
- Log: build/chat-history-batch-build.log in the build worktree.

Includes local-first search/context and history access cleanup, media receipt integrity, terminal visibility preservation and bounded prior-message lookup. The 170-file source regression passed 956 tests with 10 skips before building. Existing plugin Kotlin migration warnings were emitted; build exited successfully.

No relay endpoint, relay certificate, LAN or peer-file flags were supplied. Native device binding is compiled in, but this is service-backed runtime configuration, not public-mainnet or adaptive transport acceptance. No phone installation or device acceptance performed. This APK replaces the prior d44afcb artifact at the same path; prior audit hashes remain historical.
