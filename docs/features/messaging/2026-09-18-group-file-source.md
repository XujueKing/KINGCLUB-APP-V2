# Group file source identity

The conversation file-details and forwarding routes must retain the acknowledged
message sender, for both incoming group files and the current member's files.
The group ID remains the authorization scope; it must never substitute for a
member identity. Legacy direct messages without a sender may use the existing
self/peer fallback. Group peer downloads remain disabled in the downloader.

Validation: exercise both UI routes with received and sent group files, and run
the existing file forwarding/downloading checks. This is client route validation,
not a claim of group P2P delivery or device installation.

Result: all four sent/received x details/forwarding widget cases pass.
The existing downloader, file forwarder, forwarding page and context-media
suites pass (51 tests). No group peer-transfer capability was enabled.
