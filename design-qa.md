# Design QA — Legacy Private Storage Replica v1

- source visual truth: user-provided old-version private storage screenshot in the 2026-08-26 conversation (`580 × 1200 px`, including device frame)
- implementation screenshot: `docs/features/club/feature_private_storage/pages/page_private_storage/android_private_storage_latest.png`
- implementation pixels: `1080 × 2400`; app viewport `411 × 891 logical px` on Android API 37 emulator
- state: App Shell / private storage tab selected / wine category / page 1 / empty cabinet
- normalization: device frame and platform-owned status/home chrome excluded; app-owned content compared by viewport width and by spacing relative to the persistent bottom bar

## Full-view comparison evidence

- The implementation follows the same vertical composition: centered title, large dark-brown empty-display field, old information icon, lower wine/item selector, 3 × 3 cabinet, two pager dots and selected storage bottom tab.
- The WeChat host capsule from the reference is intentionally absent.
- The current Android bottom navigation is the already approved legacy Shell component and remains selected on the storage icon.

## Focused comparison evidence

- Fonts and typography: `私人储物柜` uses the same compact centered white hierarchy; `酒` is brighter with a thin underline and `物` is muted. Copy matches the reference.
- Spacing and layout rhythm: the cabinet was increased from `300` to `322` logical px after the first capture so its relative width and cell proportions match the old screenshot; the whole cabinet region was moved upward to preserve pager and bottom-bar spacing.
- Colors and visual tokens: background follows the legacy `#252018EF → #000000` radial treatment; cells follow the old `#7A6750 → #443626` depth with `#C9B69E55` borders.
- Image quality and asset fidelity: the center state reuses the exact old `images/fail.png` asset copied into the V2 asset bundle; it is not redrawn.
- Copy and content: the screenshot's empty state remains empty; no invented products, quantities, IDs or storage metadata are visible.

## Findings

- No actionable P0/P1/P2 mismatch remains in the app-owned storage screen.
- Platform status bar proportions differ from the old iPhone/WeChat capture and are intentionally excluded.

## Comparison history

- Pass 1 P2: the 300 logical px cabinet appeared too narrow relative to the old screenshot.
- Fix: increased cabinet and category width to 322 logical px, increased its reserved vertical region to keep bottom spacing, and captured the same state again.
- Pass 2 evidence: `android_private_storage_latest.png`; the cabinet/cell proportion, pager position and bottom-bar relationship no longer have an actionable mismatch.

## Implementation Checklist

- [x] Old empty-cabinet composition
- [x] Exact legacy information asset
- [x] Wine/item selected states
- [x] Two horizontally swipeable pages
- [x] Offline empty-state explanation
- [x] Storage bottom-tab selected state
- [x] Static analysis and widget tests

## Follow-up Polish

- A populated cabinet state needs a separate old-version reference before adding bottle/product assets.

final result: passed
