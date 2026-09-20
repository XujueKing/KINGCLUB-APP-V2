# Image route check after B login

B returned to the existing test conversation in the chat preview. Sent only
the repository fixture `assets/legacy/aa/positioningCard.png` through the system
photo picker and explicit send confirmation. A displayed the expected image.

The corresponding server access-log interval contains successful HTTP 206
downloads for both the new thumbnail (3,912 bytes) and full image (2,906 bytes).
This is not acceptance of an HTTP-free attachment transfer.

A read-only query restricted to this test message confirmed:

- uploaded source: 5,340 bytes;
- published image: 2,906 bytes;
- source and published SHA-256 values differ.

The app retains `widget.bytes` under the sent-image client ID. The service
normalizes the image into WebP. `readPeerMediaSource` correctly requires exact
size and SHA-256 agreement with the published manifest. The image prefetcher
also skips downloading the published version when the original sent-image cache
exists. Consequently that original cache alone cannot serve this published asset.
Do not weaken the digest check or label successful HTTP fallback as peer success.

Remaining implementation: align the sender's retained media with the published
representation. Prefer normalization before publishing with bounded server-side
validation, preserving animation, orientation, metadata stripping and privacy.
Account for thumbnails, voice normalization and video variants too; merely
downloading an extra server copy on every sender is not a bandwidth saving.
The current check diagnoses the image mismatch; it does not establish which
other media variants have the same mismatch, nor complete their direct routing.

No source behavior, service deployment, member relationship or security check
was changed in this diagnostic step. Only test metadata was queried; no session
credentials or private gallery images were extracted.
