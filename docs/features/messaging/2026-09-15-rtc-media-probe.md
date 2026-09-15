# Native RTC media probe — 2026-09-15

The calltest-only tool now has an opt-in KINGCLUB_RTC_MEDIA_PROBE=true mode. The user must press the on-screen start button before getUserMedia; one caller captures microphone/camera, the second local peer receives. An initialized renderer binds the received video; inbound RTP audio packets and decoded video frames are checked after ICE restart. No account store, server signaling, upload or recording file is used. Same-device host ICE is not public TURN, cross-device call delivery or audio intelligibility evidence.

Default mode remains the empty-stream DataChannel probe. Completion now preserves DATA_CHANNEL_PASSED / LOCAL_MEDIA_PASSED or the failing stage before CLEANUP_FINISHED, instead of erasing the result. calltest manifest now declares camera/microphone so the optional capture path can request them; location remains removed. Production preview manifest is unchanged.

Validation: tool analyze passed; calltest Profile ARM64 build passed (137.1MB), with capture flag true. Final SHA256: 3e6f9186e129cbdc19dabbc804944417abb493f2c19fd278f0cf86fb398142b8.

Not executed: real capture, RTP reception/decode and camera/microphone permission prompts. The earlier install attempt did not return and its exact adb install process was stopped before installing the corrected artifact. Do not record installation or media test success. The phone update remains pending.

## Failed-open cleanup callback guard

NativeCallMedia now marks itself closed before releasing resources after opening fails. This prevents native ICE callbacks raised during track shutdown from publishing events for an already failed call. Regression coverage injects an addTrack failure and a candidate callback during track.stop, verifies no candidate escapes and confirms track, stream and peer resources are released exactly once, including a subsequent close.

Validation: targeted Flutter analyze passed; native_call_media_test.dart passed all 14 tests. This is controlled lifecycle coverage, not handset call or audio-quality validation. Not yet included in the installed APK.
