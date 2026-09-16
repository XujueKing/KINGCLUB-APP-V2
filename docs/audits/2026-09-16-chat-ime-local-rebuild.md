# Confine keyboard rebuilds to bottom spacing

A installed preview 60eb0ab (main motion patch 9e49e3e), foreground verified.
The existing unsent composer text survived installation and was compared equal
without sending or rewriting it. A keyboard open/close check returned to the
conversation; no matching fatal/overflow entries appeared in the sampled log.
User feedback: improved, still not sufficiently smooth. This is not acceptance.

DirectChatPage previously subscribed to viewInsets at page level. Every IME
update recreated the conversation widget tree and message index map. The inset
dependency now belongs only to the bottom-space animation builder. Layout still
resizes the history, while existing message widgets are reused.

Eight widget tests passed, including an identity assertion for an existing
message over opening and closing inset frames, alongside exact inset following,
panel replacement, and outgoing insertion checks. These are deterministic
layout/rebuild checks, not real-device frame-time or visual acceptance.

The Android gfxinfo sample after installation had only 50 frames and 7 janky
frames; it is neither a targeted IME capture nor the Flutter frame pipeline and
must not be used to claim the remaining animation issue resolved.

Follow-up installation: preview 5fa6e73 (includes this patch and sender video
retention cb9a418) built in Profile mode, 159.2 MB. A installation returned
Success and the start script verified stable foreground on attempt 2. Opened
the existing A/B direct conversation and verified its unsent text was identical
to the pre-install text. No message was sent. B was not modified. Smoothness and
real offline video playback remain unaccepted for this build.
