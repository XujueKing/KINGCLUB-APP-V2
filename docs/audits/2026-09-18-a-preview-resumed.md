# A handset preview acceptance, 2026-09-18

User confirmed A available. B was not operated.

Installed the cfb45a7 ARM64 Profile preview with adb install -r: Success.
Artifact SHA256: 07FD4996588C61843C9E92FEA2D89D2CC0404C8A634FD3DA48D120CBCCB856FE.
No uninstall, data clearing, account changes or service deployment occurred.
Optional relay/LAN/peer-file/group-file switches remain disabled in this APK.

Observed through Android UI hierarchy and screenshots:
- App opened authenticated after the replacement install.
- Chat list retained pinned contact and the existing A/B test group.
- Group history retained prior text, voice entries and the offline pending marker
  from 06:16, now showing 06:17 without a pending prefix.
- Tapping the own avatar in group history opened the authenticated own profile:
  identity, avatar and profile fields rendered; the earlier self-message rejection
  did not appear. This verifies rendering only, not statistics correctness.
- Contacts listed an existing friend. Opening that entry showed the friend's
  profile, mutual-follow state and private-message action.

Local evidence (not committed, contains personal profile data):
- build/a-resume-group.png
- build/a-resume-own-profile.png

No new messages or calls were sent in this batch. Voice playback, delivery to B,
frame pacing, public NAT switching and comprehensive profile privacy were not
verified by these observations. A was left on the existing friend's profile.