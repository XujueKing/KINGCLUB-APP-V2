# Video preparation worker — 2026-09-15

The pre-compression SHA-256 scan now runs in a Dart isolate. Only the source path and account namespace cross the isolate boundary; native encoder callbacks stay on the main isolate. File reads remain streaming. The existing v4 cache key is unchanged, verified against a fixed SHA-256 fixture.

Leaving the page still rejects late completion before starting the encoder/upload. An already-running background hash finishes its read before the isolate exits; immediate hash cancellation is not implemented.

Validation: targeted Flutter analyze passed; all 8 chat_video_optimizer tests passed (cache reuse, account isolation, fallback, cancellation, progress ordering). No real-device responsiveness measurement or successful new video delivery is claimed. This change is not installed yet.

## File-upload preflight

The file uploader now also scans SHA-256 in an isolate with bounded streaming reads. It no longer reads secure storage for each input chunk. Credentials are checked before scanning and again before creating an upload intent; existing per-upload-chunk checks and AES-GCM wire format remain. Size changes reject the scan. The worker finishes an already-started scan if the page closes, but late results cannot begin upload.

Targeted analyze passed and 10 uploader tests passed, including loss/timeout/gateway resume, grant renewal/rejection, Unicode filenames, and revocation after scanning with zero API calls. These are controlled tests, not phone delivery evidence. This follow-up is not included in the 07:38 installed APK.

Video send diagnostics now log only stage, elapsed milliseconds and exception type. Stages distinguish opening, optimizing, uploading, processing and queueing; queued means durable outbox acceptance, not server delivery. No paths, tokens, account IDs or message content are logged. Targeted analyze and both video lifecycle tests pass.

Device update: 6abc98c workspace Profile/preview ARM64 APK built in 61.4s (149.0MB); SHA256 39fa217891db959222a715d20bfeeb6b6b9e5139711b4be7c14ab7dda9dce792. adb install -r returned Success and activity launch Status ok. Includes uploader background hashing and stage diagnostics. Existing uncommitted onboarding changes were preserved in this workspace build. Actual new send remains unverified.
