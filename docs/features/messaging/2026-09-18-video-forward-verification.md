# Video forwarding verification

Move full source-file SHA-256 calculation off the UI isolate. Pass only path and expected byte length, stream rather than load the whole video, reject growth/truncation/hash mismatch and check cancellation before refreshed authorization or upload. Preserve retry reuse and existing grant checks. No UI or media quality changes. Background hashing settles before cancellation is observed; it is not instant worker termination.

Use actual temporary files in the corrupt-source test, and verify cancellation while file loading never opens the uploader. Validation: combined forwarder/prefetch suite passed 13 tests; final forwarder rerun passed 5 tests after removing the now-unused synthetic File fixture. Analysis of both changed Dart files passed. Logs: build/video-forward-background-test.log, build/video-forward-background-final.log, build/video-forward-background-analyze.log. Not packaged or installed; no device performance claim.
