# Received voice retention while a conversation is open

DirectChatPage now schedules received voice messages from its latest 50 loaded
messages into a serial background retention worker. Direct and group sessions
use their respective authorized media endpoints. This never starts an audio
device, changes a read receipt, or blocks rendering. Existing saved assets skip
network requests; active work is deduplicated, failures back off for 30 seconds
until a later message/history update. Queue and retry metadata are bounded to
the recent window. Leaving or changing the account disposes the worker.

Each missing file requires a validated grant and a second authorization after
the download before publishing the account-scoped voice asset mapping. The
existing MediaCache audio size limit and persistent storage policy apply.

Validation: 12 tests passed across the worker, composer, and outgoing scroll
tests; analyzer passed all three changed source/test files. Worker tests cover
deduplication, successful retention, revoked permission, session change, and
ignoring own/non-voice rows. These use a synthetic cache/network and do not prove
phone playback. This patch is not yet installed.

Remaining scope: real phone receipt without tapping followed by offline playback;
retention for unopened conversations and messages received while the app is
backgrounded; old voices outside the recent window still use on-demand loading.
This is progress toward offline media availability, not complete offline sync.
