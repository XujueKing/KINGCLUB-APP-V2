# Group peer authority client contract

Extend authenticated file authority requests with optional group scope and require
the expected group ID from the caller. Validate the service-returned group ID
and unsigned membership versions for both endpoints. Compare these fields on
every renewal so leave/rejoin cannot retain the previous transfer authority.
Direct scope must reject group responses, and group scope must reject legacy
direct responses. Keep direct request payloads unchanged.

This is the authorization foundation, not enabled group peer transport. Device
directory capabilities, real-member directory integration and real-device verification remain
pending. No UI changes, phone installs or backend deployment in this batch.

## Implemented and checked

PeerFileChannel accepts a fixed group ID for an independently authenticated
lane. Group control packets use version 2 with exact group scope; direct
packets retain version 1. Serving, receiving and renewal validate membership
epochs; completion also compares the renewed sender authority.

Validation: 18 authority unit tests passed; analysis passed for five changed
Dart files. A first generic run skipped 26 native cases because the environment
was unset. Then explicitly loaded the native DLL (SHA256
B18317E2C587A58C45A6628FF58E86E13A9B0F2227778064FB56A8FB553DFC7C)
and ran all five encrypted UDP negotiation cases: direct success, cache miss,
wrong member, group success and changed membership epoch. All five passed,
none skipped. Transfers use actual local encrypted UDP and encrypted file
cache, with mocked HTTP authority responses. This is not live group membership
or phone acceptance. Group-only peers still require scoped device directory
and handshake support before the downloader can enable this path.
