# Actual image peer → HTTP automatic resume

Installed A/B build: 882e422b, unchanged from the media-lane verification.
This check used only a synthetic 2560×2560 FFmpeg testsrc2/noise PNG, selected
through B's actual photo picker and sent to the authorized A test account.
The source PNG was 14,284,887 bytes; the application's canonical WebP was
3,310,848 bytes. No private gallery image was used.

Message: `9db9b1b9-83ad-405f-b8b4-4515511462a7`.

- 08:18:14.162: B logged `source-ready media=image` (233 ms).
- 08:18:29.278: stopped only B's preview application while A's receiving.part
  high-water length was 2,386,320 bytes. High-water length alone is not proof
  of a complete contiguous block.
- 08:18:33.188: A's peer download failed with TimeoutException, approximately
  3.91 seconds after the stop. Authenticated ingress counted UDP 2,428 frames /
  2,369,728 bytes and relay 285 frames / 278,160 bytes. These include retries;
  they are not unique-file-byte totals.
- 08:18:34–35: the server recorded two image HTTP 206 responses, 1,048,576 and
  165,120 bytes. Their total, 1,213,696, is exactly the canonical size minus
  2 MiB. There was no full-image HTTP request before interruption. The earlier
  3,860-byte thumbnail request is separate and excluded.
- A's two persistent full-image cache entries and B's canonical sent cache all
  had size 3,310,848 and SHA-256
  `d862c9b89320beabd7a3bf8d8d135517861ca39ef7ea593d9eb6d05f21b2e773`.
  A displayed the synthetic image normally. No retry tap, page restart or
  receiver interaction was used to initiate fallback. B was reopened afterward.

This demonstrates automatic actual-image handoff, reuse of 2 MiB of received
blocks and final persistent content integrity on the current same-LAN pair.
The access log records response lengths, not request Range headers; it is not
claimed to expose individual requested offsets. Public cross-network,
background and sustained-loss behavior remain separate acceptance items.
