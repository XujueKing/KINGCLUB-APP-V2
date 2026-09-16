# Sender image retention

Selected image bytes are retained in the member-scoped persistent media store
before message queueing. The sender keeps one client message ID and reuses the
uploaded asset after a retention failure. Session changes prevent late queueing.
The existing draft is cleaned up only after queueing, independently of the
retained image. Full and thumbnail views of own messages can use that copy
without a download grant. Permission denial evicts the sender mapping as well
as both message variants. Other members do not receive this local mapping.

MediaCache.importBytes shares the existing atomic local-file writer, scope
hashing, cancellation generation, and retention policy. The bytes are copied
before asynchronous work so callers cannot mutate an in-flight save.

An existing image session-change test exposed an unobserved replacement future
when its widget is removed before FutureBuilder subscribes. CachedMediaImage
now observes that future immediately, while preserving its original error for
the mounted FutureBuilder to render.

Validation: 37 media/image/video-routing regression tests and one new image
sender retention/retry test passed. Six changed source/test files passed analyzer.
The real PNG tests reopen the disk store and decode own full/thumbnail images
without repository requests. Sender network/queue tests use doubles; these do
not establish real service delivery or phone offline acceptance. No new phone
build was installed at the time of those checks.

Installation follow-up: preview 39cd93f built in Profile mode (155 seconds,
159.2 MB), installed successfully on A, and foreground was verified on attempt
1. Returned to the A/B direct conversation. A project-owned PNG was copied to
Download/KINGCLUB-retention-test.png and registered with the media scanner, but
not selected or sent. The composer contained unsent text different from the
pre-install snapshot; it was left untouched rather than overwritten. Phone
photo sending/offline viewing, animation smoothness, and video offline playback
remain pending. B was not operated or updated.
