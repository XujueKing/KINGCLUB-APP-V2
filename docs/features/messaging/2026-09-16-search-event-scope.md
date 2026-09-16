# History search notification scope

Problem: any group read or membership notification cleared every open history search, including unrelated single chats, resetting already loaded pages and issuing a new query.

Group details now pass their group ID to history search. Search uses the existing conservative media-scope filter: explicitly unrelated groups cannot reset results; current/unknown scope and reconnect still revalidate. Single-chat search ignores group notifications. Existing direct read notifications retain conservative invalidation because that page does not yet receive its conversation ID. Session invalidation and late-response guards remain unchanged.

Validation: all 4 search widget tests and static analysis of 3 files passed. Tests for single/group search retaining results and query count on unrelated events, and current privacy changes still clearing/reloading. Real multi-phone notification acceptance remains pending. This does not add media-type search: locating recordings by type remains an open functionality gap.
