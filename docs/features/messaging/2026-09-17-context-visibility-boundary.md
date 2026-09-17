# Context visibility boundary

Reference/search context reads two independent history pages. Previously it checked the second page's hidden/admission boundary only, so a lagging second snapshot could undo a boundary observed in the first page.

Both page boundaries now require valid nonnegative 32-bit sequence values, including group admission where membership information exists. The displayed window uses the maximum observed boundary across both pages. Existing membership/history revision agreement remains required. A selected message at or below that boundary remains unavailable.

Validation: 28 context, offline, refresh and media tests passed; new cases cover first-page clear/admission followed by a lower second-page boundary, and missing/negative/oversized/string boundary values in either page. Two-file Dart analysis passed. Log: build/chat-context-boundary.log. No UI changes, phone installation or server deployment; source postdates the 758ab7d APK. This verifies the two-response visibility rule, not all search privacy or multi-device scenarios.
