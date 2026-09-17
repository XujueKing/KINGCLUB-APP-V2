# Peer file fallback cancels the abandoned attempt

The peer-opening deadline already switched downloads to HTTP after three seconds, but the activity callback supplied to member discovery/handshake remained true until the entire download ended. A late peer attempt could keep trying candidates while HTTP was in progress.

The downloader now owns a separate peer-attempt activity flag, cleared in the peer path's finally block before HTTP fallback. The enclosing download remains active; HTTP still reauthorizes, verifies size/digest, and stores its result using existing paths. Late peer handles continue to close rather than becoming active downloads.

Validation: all 31 file-downloader tests passed. The new timeout case suspends peer opening, checks its activity flag is already false inside the fallback authorization request, verifies exact HTTP bytes/request counts, releases the late peer continuation and checks no reactivation. The strengthened timeout case was rerun separately and passed; analysis passed. This is a controlled regression, not public-network or phone acceptance.

The real member-HTTP integration fixture was not present under the current app build artifacts, so that gated test remains unverified this turn. No devices or services deployed.
