# HarmonyOS adapter sources

These files are used only by the isolated Harmony build. They are not dependencies
of the Android/iOS application. Current acceptance status is recorded in
`docs/features/foundation/harmony/README.md`.

## Secure storage

The local plugin implements the existing FlutterSecureStorage method channel.
`stage-harmony-secure-storage.ps1` copies the pinned 11.1.0 Dart package with its
license, adds the OHOS platform registration and selects the Harmony policy.
Application call sites and Android/iOS packages are unchanged.

- A random AES-256 root key is protected by Asset Store Kit: first unlock,
  no device sync, no retention on uninstall.
- Each preferences value is `v1:` plus base64 of nonce (12 bytes), GCM tag
  (16 bytes), and encrypted JSON string. AAD includes its storage key.
- The plaintext is returned only after GCM authentication succeeds. Empty,
  Unicode and session JSON values over 1024 bytes are supported by the format.
- The preferences file is private to this plugin; deleteAll clears only this file.
  The root key is retained until uninstall. A missing root with existing
  ciphertext fails rather than silently creating a replacement.
- Only Asset NOT_FOUND is treated as absence. Other errors return a sanitized
  PlatformException without recording values, key names or native error messages.
- Calls are serialized per engine. Cross-engine concurrent mutations are not
  validated; Harmony background message engines are not enabled in this build.
- This does not implement biometric prompts or migrate data from the rejected
  preferences-based RSA plugin, which was never installed for KINGCLUB.

## Device verification (not yet executed)

1. Copy `verification/storage_probe.dart.template` to the isolated application's
   `lib/harmony_storage_probe.dart`. Do not copy it into the primary app checkout.
2. With valid developer signing, build/run this target with the real API base
   and `--dart-define=HARMONY_STORAGE_PHASE=write`. Require
   `HARMONY_STORAGE_WRITE_PASS`. It checks empty strings, a large Unicode value,
   ordered writes, and persists a dedicated diagnostic marker. No credentials
   are printed or deleted.
3. Stop the app, rebuild the same bundle with phase `read` without clearing data,
   and launch it. Require `HARMONY_STORAGE_RESTART_PASS`. It checks persistence,
   idempotent deletion and absent-key results, then starts the real app.
4. On a dedicated test install, verify ciphertext tampering / key swapping fails,
   device reboot before and after first unlock, OS storage errors, and missing
   Asset key with ciphertext present. These cases remain unverified.
5. Verify real login, logout and relaunch. Validate the cover video and both music
   tracks, sound toggle, transition to phone login and foreground/background.

The probe has passed Dart analysis; the adapter has passed HAP compilation.
Neither result proves native cryptography, persistence or media playback on device.

## Build

Use the preparation scripts in order: prepare-harmony-probe,
stage-harmony-storage, stage-harmony-secure-storage, stage-harmony-video.
Each staging script requires a fresh destination for its packages; it refuses to
overwrite an earlier experiment. Sources and commit pins are in the scripts.
`build-harmony-device.ps1` requires an explicit HTTPS API base, preventing the
default mock auth repository from being used unintentionally. `-Unsigned` makes
a compile-only package. Signing material stays outside the repository.
