# Return media composers after durable queue ownership

Image/video/file and location confirmation must stop waiting for the remote
acknowledgement once the controller reports durable queue ownership. The chat
controller continues delivery and updates the bubble status; local media source
retention and draft cleanup still complete before closing media composers.
Queue write failures keep the composer and draft available. A controller that
returns without queueing is an error. Late transport completion is observed but
does not falsely turn an already queued message into a composer failure.

No transport retries or server acknowledgement semantics change. Consolidated
queue boundary, media recovery/session and location checks follow implementation.

Validation: 20 tests passed across queue completion, image response/retention,
file recovery/session, media preview session, and location drafts/picker. The
image route test holds remote acknowledgement pending and verifies the composer
returns, then observes a late network failure without a second send.
No APK was installed; real-device interaction remains pending the combined build.

Voice follow-up: VoiceDraftSender now returns after local audio retention and
durable queue ownership, without waiting for message transport acknowledgement.
Source leases remain held through journal/draft cleanup. Upload or queue failure
preserves the recording. 21 voice sender/store/preview and queue tests passed;
Dart analysis passed. A held-network controller test verifies retained bytes and
one pending message after a late network failure. Device verification pending.
