# A handset preview installation

Source: app 38fd1f1 plus the reviewed native source pin update in this node. Existing unrelated working-tree files were preserved. The SUPERVM source moves from 6939dc96 to 579008d18db917bd2e12610a8d1f93bebbef3f51; the complete diff contains only the relay daemon egress budget and its documentation. The four native protocol source files guarded by the build script are unchanged and clean. The exact revision guard remains enabled. SUPERVM remote push is still unavailable to the current account; this is not a claim of upstream publication.

Build: preview/Profile, Android ARM64, real HTTPS service, device binding, peer-file and LAN switches enabled. Gradle completed in 68.8 seconds; the build script verified the packaged native library is ARM64 ELF. APK SHA256: ED8C463632B0B1061AF400023C7663D1BC928E199DBC390B157B5E4398C0429E.

ADB replacement installation succeeded on A only. Foreground stability check passed on the first launch attempt. Actual UI inspection confirmed:

- Existing login restored into the application.
- Existing A/B single-chat and test group remained listed.
- A/B history displayed voice and video call durations and prior messages.
- Opening emoji moved the visible conversation upward; built-in categories and the private sticker category appeared.
- Private sticker category showed its add tile; screenshot visually inspected.

No messages were sent, recordings created, stickers imported, or B operations performed. Local evidence: build/sticker-capacity-preview-build.log, build/sticker-capacity-ui.xml, build/sticker-capacity-A.png (not committed because handset content is private).

Limits: this confirms installation and basic real-device UI only. Capacity boundaries were covered by the prior 28 local tests, not by filling the real member library. Cloud migration 120 remains undeployed; cross-device sticker recovery, new peer-route behavior on two phones and voice transcription handset acceptance remain open. Enabling transport flags does not prove peer connectivity.
