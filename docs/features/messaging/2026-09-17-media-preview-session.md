# Media preview session invalidation

Bring image/video preview behavior in line with file sending: immediately hide
old-account content, disable send/discard, cancel image upload and ignore late
UI completion after a session change. Keep durable drafts for their original
account. Recheck session usability after queueing before draft/upload cleanup.
No visual changes while the original session is valid.

Consolidated image/file/video recovery and session checks follow implementation.
Real-device acceptance remains pending.

## Validation

14 automated tests passed across media preview session, file session, queued
file/image/video recovery, image retention and durable file draft storage.
New cases verify image content removal, video filename removal, disabled send
and discard, late image-uploader creation, and preservation of original drafts.
The video player test double does not initialize a native decoder: actual frame
removal/audio stop remains a real-device acceptance item. Changed Dart files
pass static analysis. No build or phone installation in this batch.
