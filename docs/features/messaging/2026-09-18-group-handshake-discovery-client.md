# Client group handshake discovery

Publish API709 context before sending the signed native offer; validate the
source/target device identities and exact 16-byte native session ID. Only
accept a positive receipt with a bounded future expiry. Incoming resolver
validates all returned identifiers and scope, then rechecks current directory
keys, membership epochs and expiry before exposing the expected scope.
No group identity is persisted into the offline friend cache.

Automatic runtime dispatch and downloader routing remain pending. This change
requires service migration126; group mode remains opt-in and undeployed.

Validation: seven native device-binding cases passed, now including context
publication, successful incoming resolution and mismatched/invalid native
session rejection. Four-file analysis clean. Real loopback SuperVM WSS
integration passed after publish-before-offer wiring; directory/context HTTP
responses are test fixtures, not a deployed service. Temporary owned relay
terminated in finally. No APK installation or phone operation.
