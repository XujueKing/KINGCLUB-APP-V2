# Video preparation worker — 2026-09-15

The pre-compression SHA-256 scan now runs in a Dart isolate. Only the source path and account namespace cross the isolate boundary; native encoder callbacks stay on the main isolate. File reads remain streaming. The existing v4 cache key is unchanged, verified against a fixed SHA-256 fixture.

Leaving the page still rejects late completion before starting the encoder/upload. An already-running background hash finishes its read before the isolate exits; immediate hash cancellation is not implemented.

Validation: targeted Flutter analyze passed; all 8 chat_video_optimizer tests passed (cache reuse, account isolation, fallback, cancellation, progress ordering). No real-device responsiveness measurement or successful new video delivery is claimed. This change is not installed yet.
