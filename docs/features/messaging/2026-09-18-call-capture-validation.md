# Required media tracks at call startup

Direct calls previously continued after capture even with no microphone track. Group calls checked microphone but did not require camera for video mode. Reject missing required tracks before foreground service/peer publication and release acquired capture/transports. This handles empty capture results; a present but system-muted track is distinct and not claimed detected. Preserve intentional in-call microphone/camera mute behavior and existing UI.

Validation: 49 direct/group native media and call-session tests passed; four-file static analysis passed. New cases return partial capture streams missing audio or video, assert direct peer creation/group publication is skipped and remaining tracks, streams and group transports are released exactly once. This validates lifecycle behavior with injected media results, not physical camera/microphone permission behavior. No APK rebuilt or phone installed.
