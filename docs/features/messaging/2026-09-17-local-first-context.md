# Local-first message context — 2026-09-17

Opening a saved search/quoted message now reads its local encrypted context alongside the remote bounded history window. Previously it waited for a network failure before trying the saved window. Local success appears immediately; remote success refreshes it, NETWORK_ERROR reuses the same local read, and other failures clear the visible context. Generation/session/deletion fences reject late completions. Positioning is scheduled only once per load, so the remote refresh does not force a second jump after the local preview. Background read-receipt refresh retains its existing behavior and does not reinsert a local preview.

Shared context application preserves visibility filters and stops voice playback when its message is absent from the authoritative result. No change to bubble design, stored history format or media access APIs.

Validation: 26 tests passed across offline context, context refresh, context media and call-history callback suites; analysis of both changed Dart files passed. New cases verify content is visible while the network future is pending, replacement by remote success, offline reuse without a second disk read, and explicit-denial removal. Existing cleanup/logout/media playback checks passed. The old fallback test now expects one proactive local read for all outcomes while still requiring that denied results are not visible.

Not rebuilt or installed on phones. These tests do not prove real-device frame smoothness or complete chat delivery.
