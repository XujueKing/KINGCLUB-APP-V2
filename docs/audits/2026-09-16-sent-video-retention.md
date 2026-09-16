# Sender video retention

ChatVideoSendPage retains the prepared upload input in the account-scoped
persistent MediaCache before queuing the video message. A stable client message
ID links the retained copy to the eventual server message. Queue retries reuse
that ID and the prepared upload. Draft cleanup does not delete the retained copy.

Own video playback checks the normal message cache, then the sender copy, before
requesting a media grant. Its card can open without a downloaded poster. Remote
messages cannot use another member's sender key. A revoked permission evicts
both message variants and the sender copy. A failed local decode evicts the
actual copy attempted before falling back to the existing network player path.

Validation: 14 tests passed across chat_video_send_lifecycle_test,
chat_video_cache_authorization_test and chat_video_view_test. New coverage checks
retention failure prevents queueing, retry preserves the identity/prepared asset,
and a fresh disk-store instance can read the retained bytes after source deletion
without a grant request. The latter uses a fake video player and synthetic bytes:
it establishes storage/routing, not native codec or audiovisual correctness.
Analyzer reported no issues in the sender and playback files.

A/B were absent from ADB. No device installation or real offline playback has
been performed for this patch. Existing videos sent before this mapping was
introduced still require their existing message cache or a first download.
