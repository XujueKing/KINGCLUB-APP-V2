# Design QA — Legacy Contacts Header v1

- source visual truth: user-provided old-version contacts header screenshot in the 2026-08-26 conversation (`539 × 96 px` crop)
- implementation screenshot: `docs/features/social/feature_contacts/pages/page_contacts/android_contacts_legacy_header_latest.png`
- implementation pixels: `1080 × 2400`; compared header region is the app-owned content below the Android status bar
- viewport: Android API 37 emulator, `360 × 800 dp`, device pixel ratio `3`
- state: App Shell / message tab / contacts selected / normal Fake contacts list
- density normalization: relative positions and app-owned header proportions compared after normalizing both captures to viewport width; Android status bar excluded from fidelity findings

## Full-view comparison evidence

- The implementation preserves the current contacts search, shortcuts, alphabet groups, side index and bottom navigation while replacing only the header requested by the user.
- Header hierarchy matches the reference: black background, outlined plus on the left, centered `通讯录 / 聊天`, contacts selected, and a low-contrast divider below.
- The reference's right-side WeChat host capsule is intentionally absent, as explicitly requested.

## Focused header comparison evidence

- Fonts and typography: selected `通讯录` uses the larger bold champagne treatment; `聊天` uses the smaller low-opacity inactive treatment. Copy matches exactly.
- Spacing and layout rhythm: plus and tab group share one vertical center; tab group is centered independently from the left action; divider spans the header with equal side insets.
- Colors and visual tokens: pure black background and `#C9B69E`-family active/inactive treatments match the existing legacy chat header.
- Image quality and asset fidelity: the header contains no custom raster artwork; the outlined add control uses the closest Material icon and remains sharp at device density.
- Copy and content: only `通讯录` and `聊天` remain in the title area; the former subtitle, test button and more button are removed.

## Findings

- No actionable P0/P1/P2 mismatch remains in the requested header region.
- The Android system status bar differs from the old WeChat capture by platform ownership and is intentionally excluded.

## Comparison history

- Initial implementation showed a large left-aligned contacts title, subtitle, test icon and more icon; these were the user's reported P1 mismatch.
- Fix applied: replaced that region with the approved old-version header structure and kept the contacts body unchanged.
- Post-fix evidence: `android_contacts_legacy_header_latest.png`; no actionable P0/P1/P2 issue remains.
- 2026-08-28 accessibility pass found a P2 13 px bottom overflow in both shortcut cards at 200% text scale. Fix applied: shortcut cards now use a text-scale-aware minimum height. Post-fix widget evidence confirms no overflow; the approved normal-scale header and body composition are unchanged.

## Implementation Checklist

- [x] Old-version header hierarchy
- [x] Right-side host/actions omitted
- [x] Add-friend Fake intent
- [x] Contacts/chat switching
- [x] Existing contacts body preserved
- [x] Static analysis and widget tests
- [x] 200% text-scale layout and scrollability

## Follow-up Polish

- None required for this approved header crop.

final result: passed
