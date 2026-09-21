# HTTP timeout: early peer recovery

The downloader currently waits for three retryable HTTP failures before trying
peer recovery. A stalled response can therefore consume three 30-second idle
windows even when the sender has returned. Preserve normal HTTP retries, but
try the existing authorized peer path once after the first HTTP timeout during
a download. If unavailable, continue the HTTP retry budget and retain the final
exhaustion recovery attempt. Non-timeout errors keep their existing behavior.

Reuse complete encrypted cached blocks, verify the final hash and authorization,
and preserve cancellation/deletion semantics. This changes neither the protocol
nor UI. Automated handoff checks must cover file and all existing media kinds;
this document does not claim actual-phone or public-network acceptance.

Validation: 66 downloader/handoff tests passed, including early timeout recovery
and an unavailable early peer followed by ordinary HTTP retries and final peer
recovery for file, image, thumbnails, voice, H.264 and HEVC references. Successful
early recovery requests HTTP blocks [0, 1] instead of [0, 1, 1, 1], retains the
first complete block and verifies the resulting file. Static analysis and diff
checks passed. These tests inject transport failures, not a measured carrier
outage; device installation and real timeout acceptance are still outstanding.
