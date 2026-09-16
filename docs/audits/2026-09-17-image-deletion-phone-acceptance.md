# A image deletion acceptance

Device A 462606d8, installed preview 2a8c93b. Used the project-owned wine_flip.png
test message previously sent in the authorized A/B direct conversation. Long
pressed that image, selected 为我删除 and confirmed the single-message dialog.
No other message or whole conversation was deleted; B was not operated.

Before deletion, exactly one app-private media file matched source SHA-256
9c7fb4fb926a496296d49e3f9230e6dbac0acb938393a812fd3d7d613ca6ba0f.
After deletion no app-private media files matched. The image disappeared from
the conversation while adjacent existing text messages remained visible.

Disabled Wi-Fi/mobile data and required Android `Active default network: none`
before force-stop/cold start. Opened Messages and the same conversation offline:
the deleted image remained absent and adjacent text remained. Connectivity was
still none after capture. Finally restored both network services; subsequent
inspection reported active default network 133. The original test PNG in
Download remained with its original digest.

Local screenshots (not committed: contain chat content) are preview build/
kingclub-delete-check.png, kingclub-deleted-image.png and
kingclub-offline-delete.png. Source-copy precheck is deletion-image-matches-before.txt.

Acceptance scope: this sent image, its exact-byte private source copy, retained
adjacent text and offline restart. Does not prove deletion of all transformed
aliases, voice/video/files, group deletion, full-history clear or B-side state.
