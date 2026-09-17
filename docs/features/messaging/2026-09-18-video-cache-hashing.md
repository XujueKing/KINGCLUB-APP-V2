# Video cache integrity work off the UI isolate

Recent sent-video backfill currently streams bytes asynchronously but computes SHA-256 on the UI isolate. Move the bounded streaming digest into a separate isolate; pass only the file path and expected size. Keep the byte-count and digest checks, refreshed authorization, member scope and deletion guards before durable import. No UI, automatic download policy or network protocol changes.

Deletion still waits for the active operation to settle; the worker must not import or request refreshed authorization after cancellation. Hashing is not an instantaneous cancellable operation. Validation: all 8 existing video-prefetch tests passed (direct/group, corruption rejection, deletion during grant, disk reopen and no duplicate download); Flutter analysis of the changed source passed. No device performance claim or installation. Logs: build/video-cache-hashing-test.log and build/video-cache-hashing-analyze.log.
