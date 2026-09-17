# Group file runtime integration

Opt-in KINGCLUB_NOVORUDP_GROUP_FILES requires backend migrations124-126.
Resolve incoming native handshake context through API709 before accepting a
group lane. Separate arrival stream and group/message/membership connection
keys keep group file lanes out of private text consumers. Missing context may
fall back only to ordinary live friend authorization; other errors fail closed.

File download coordinator now passes group scope into peer transport, obtains
live group authority, opens the scoped lane and restricts its file controls to
the authorized message. Existing HTTP download remains the fallback. Default
flag stays off until real backend and device acceptance.

Validation: real loopback SuperVM WSS runtime tests passed in both primary
route modes (2 cases). Receiver automatically resolved published handshake
context and downloaded 4097 exact bytes from sender's encrypted local file
cache. Group arrival count was 1 and direct arrival count 0 during transfer;
subsequent direct text and foreground reconnect assertions also passed. Native
UDP negotiation tests passed (5), including rejecting a different message on
a scoped lane before authorization; downloader regression tests passed (31).
Seven-file analysis clean. Native DLL SHA256
B18317E2C587A58C45A6628FF58E86E13A9B0F2227778064FB56A8FB553DFC7C.

HTTP directory, file authority and context services in runtime tests are
fixtures. Real Redis/SQL/HTTP integration, Android A/B acceptance, Internet
NAT traversal and production bootstrap remain unverified. Temporary local
relay closed in finally. No phone operation or deployment.
