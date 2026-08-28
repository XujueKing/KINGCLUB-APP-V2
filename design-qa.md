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

---

# Design QA — Legacy Messaging Batch

- source visual truth: user-provided legacy conversation-list screenshot plus old Mini Program sources `KingClub-app/pages/sysmessage`, `pages/chat`, `pages/chat_more`, and `pages/chat_more_select`
- implementation screenshots:
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_conversations_with_flows.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_conversation_unread.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_conversation_swipe_actions.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_conversation_long_press_menu.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_conversation_delete_confirm.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_system_unread_three.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_system_unread_two.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_system_all_read.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_conversation_offline_refresh.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_conversation_refresh_recovered.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_conversation_scenario_menu.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_conversation_relationship_readonly.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_conversation_relationship_readonly_dialog.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_conversation_invalid.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_conversation_invalid_dialog.png`
  - `docs/features/messaging/feature_conversation_list/pages/page_conversations/android_conversation_invalid_recovered.png`
  - `docs/features/foundation/feature_app_shell/pages/page_app_shell/android_message_badge_five_chat.png`
  - `docs/features/foundation/feature_app_shell/pages/page_app_shell/android_message_badge_four.png`
  - `docs/features/foundation/feature_app_shell/pages/page_app_shell/android_message_badge_two.png`
  - `docs/features/foundation/feature_app_shell/pages/page_app_shell/android_message_badge_zero.png`
  - `docs/features/messaging/feature_system_notifications/pages/page_system_notifications/android_system_notifications.png`
  - `docs/features/messaging/feature_system_notifications/pages/page_system_notifications/android_system_three_unread.png`
  - `docs/features/messaging/feature_direct_chat/pages/page_direct_chat/android_direct_chat_wechat_flow.png`
  - `docs/features/social/feature_friendship/pages/page_friend_requests/android_friend_accepted_prompt.png`
  - `docs/features/messaging/feature_direct_chat/pages/page_direct_chat/android_friend_accepted_chat.png`
  - `docs/features/messaging/feature_direct_chat/pages/page_direct_chat/android_chat_attachment_panel.png`
  - `docs/features/messaging/feature_direct_chat/pages/page_direct_chat/android_chat_image_message.png`
  - `docs/features/messaging/feature_direct_chat/pages/page_direct_chat/android_chat_media_preview.png`
  - `docs/features/messaging/feature_direct_chat/pages/page_direct_chat/android_chat_message_actions.png`
  - `docs/features/messaging/feature_direct_chat/pages/page_direct_chat/android_chat_quote_draft.png`
  - `docs/features/messaging/feature_direct_chat/pages/page_direct_chat_details/android_direct_chat_details.png`
  - `docs/features/messaging/feature_direct_chat/pages/page_contact_selector/android_contact_selector.png`
- implementation pixels: `1080 × 2400`; Android emulator app viewport approximately `411 × 891 logical px`
- state: conversations ready; system notices ready/unread; direct chat ready; details ready; selector ready/unselected
- normalization: platform status/home chrome excluded; app-owned regions compared at the same Android viewport

## Full-view comparison evidence

- Conversation list matches the supplied old screen in black canvas, centered “通讯录/聊天” tabs, muted pinned bar, King Club row and persistent legacy bottom bar. A Fake friend row was added below the system row so the approved direct-chat flow is reachable.
- The four internal screens reproduce the layout documented by the old WXML/WXSS and render without overflow or persistent-control obstruction.
- Direct chat now follows the confirmed WeChat-style reading order: the date and friend-established reminder appear first, then messages flow from top to bottom; the composer remains fixed at the bottom without pulling a short history down to it.
- The incoming-request Fake path is continuous: accept updates the request to “已添加”, presents a completion reminder, and “发消息” opens the same peer's chat with the friend-established system line first.
- The composer now demonstrates empty/enabled send states, a legacy-style three-item attachment panel, recognizable local image/video/card content, media preview and a quoted-message draft strip. Long press exposes copy, quote, forward, local delete and recall, with confirmation for destructive actions.
- The conversation list now demonstrates a numeric unread badge, legacy-style left-swipe action strip, equivalent long-press menu, local pin/unpin grouping and a guarded delete confirmation. The protected KING CLUB system row remains non-deletable.
- System-notification unread state is now continuous across navigation: the KING CLUB row starts at three, reading one card returns it at two, and “全部已读” removes only the system badge while leaving the friend unread state unchanged.
- The persistent message-tab badge now aggregates the two visible Fake sources without changing the legacy bottom-bar geometry: system `3` plus friend `2` displays `5`, then reading one system notice, all system notices and the friend conversation produces `4`, `2` and hidden states. Merely entering the message branch does not clear it.
- Pull-to-refresh now demonstrates a non-destructive local failure and recovery. The narrow offline banner uses the existing brown/gold hierarchy, keeps both rows and the bottom bar visible, and disappears after retry without reordering or mutating unread state. The old source's hard-disabled conversation search remains absent from the normal replica.
- Relationship-ended and invalid-conversation states now stay within the same old row geometry. Their Fake controls are confined to the existing long-press sheet; read-only and invalid taps are blocked by clear brown/gold dialogs, and local recovery returns to the unchanged ready layout. No permanent debug control was added to the screenshot-matched first screen.
- A same-state old runtime screenshot is unavailable for the four internal screens, so pixel-level 1:1 comparison cannot be completed in this pass.

## Required fidelity surfaces

- Fonts and typography: hierarchy, weights, wrapping and Chinese fallback match the existing V2 legacy pages; no visible truncation.
- Spacing and layout rhythm: fixed headers, card/list widths, message alignment, grouped settings and bottom composer follow old rpx proportions.
- Colors and visual tokens: black/black-red canvases, `#C9B69E` gold, old translucent panels and green sent/switch states are preserved.
- Image quality and asset fidelity: existing old `logo_2.png`, `gold.png`, `back.png` and `touxiang.png` assets are reused without generated substitutes.
- Copy and content: old labels are retained; removed-scope红包、金币转赠、礼物和群管理 entries are not exposed. All records are synthetic Fake data.

## Findings

- [P2] Exact internal-screen visual comparison is blocked.
  - Location: system notifications, direct chat, chat details and contact selector.
  - Evidence: implementation screenshots exist, but the old Mini Program runtime screenshots for the same states could not be captured because Windows Computer Use was unavailable; WXML/WXSS is not a visual artifact under the QA gate.
  - Impact: layout and interaction are verified, but small font/spacing differences cannot yet be classified as 1:1.
  - Fix: capture the four old runtime screens at the same state, place each beside its Android implementation, then resolve any visible P1/P2 drift.

## Comparison history

- Pass 1: Android screenshots captured for all five messaging screens; no overflow, clipping, bottom-bar collision or broken asset was found.
- Pass 2 P1: the reversed message list bottom-aligned a short chat history, leaving a large empty region above it and making the conversation appear squeezed against the composer.
- Fix: restored chronological top-to-bottom layout, inserted the friend-established system reminder before the first message, and retained automatic scrolling only after new content exceeds the viewport.
- Pass 2 evidence: `android_direct_chat_wechat_flow.png`; the message flow starts below the header and no longer clusters at the bottom.
- Pass 3 evidence: `android_friend_accepted_prompt.png` and `android_friend_accepted_chat.png`; the accepted peer name is preserved across the transition and the system reminder precedes chat content.
- Pass 4 evidence: `android_chat_attachment_panel.png`, `android_chat_image_message.png`, `android_chat_media_preview.png`, `android_chat_message_actions.png` and `android_chat_quote_draft.png`; no text placeholder, overflow, composer collision or unreadable operation state remains in the expanded chat interaction.
- Pass 5 evidence: `android_conversation_unread.png`, `android_conversation_swipe_actions.png`, `android_conversation_long_press_menu.png` and `android_conversation_delete_confirm.png`; the conversation actions are legible, do not overlap the persistent bottom navigation and preserve the old gray/orange/red action hierarchy.
- Pass 6 evidence: `android_system_three_unread.png`, `android_system_unread_three.png`, `android_system_unread_two.png` and `android_system_all_read.png`; three/partial/zero unread states are visually distinct, aligned with the date column and do not shift either conversation row.
- Pass 7 evidence: `android_message_badge_five_chat.png`, `android_message_badge_four.png`, `android_message_badge_two.png` and `android_message_badge_zero.png`; the aggregate badge stays inside the message icon's corner, remains legible over selected navigation, and disappears without moving any bottom-bar item.
- Pass 8 evidence: `android_conversation_offline_refresh.png` and `android_conversation_refresh_recovered.png`; the error banner and feedback clear the persistent navigation, preserve the row hierarchy and return to the unchanged legacy ready layout.
- Pass 9 evidence: `android_conversation_scenario_menu.png`, `android_conversation_relationship_readonly.png`, `android_conversation_relationship_readonly_dialog.png`, `android_conversation_invalid.png`, `android_conversation_invalid_dialog.png` and `android_conversation_invalid_recovered.png`; the expanded sheet fits without overflow, abnormal summaries remain single-line and the blocking dialogs preserve clear primary/secondary actions.

## Implementation checklist

- [x] System notice cards, expansion and local read state
- [x] Direct-chat text, attachments, retry and long-press actions
- [x] Recognizable Fake media, fullscreen preview, copy/quote feedback and destructive-action confirmations
- [x] Friend-established reminder and WeChat-style chronological message layout
- [x] Incoming friend request → accepted reminder → matching direct chat Fake flow
- [x] Chat details settings, search, permissions and clear confirmation
- [x] Contact search, sort, single-select and forwarding confirmation
- [x] Conversation-list navigation and all return paths
- [x] Conversation unread, read/unread, pin/unpin, swipe/long-press and guarded local deletion
- [x] System-card single/all-read state synchronized with the KING CLUB conversation badge
- [x] System and friend unread synchronized with the persistent Shell message badge, including `0` and `99+` boundaries
- [x] Legacy pull-to-refresh partial failure, cached-row preservation and local retry recovery
- [x] Relationship-ended read-only summary, invalid-reference blocking, generation-safe local recovery and normal-state reset
- [x] Static analysis and widget tests
- [ ] Same-state old runtime screenshots and final pixel comparison

final result: blocked

---

# Design QA — Legacy Edit Profile

- Source visual truth: old Mini Program `pages/myinfo/myinfo` at `master / 505d222 / 1.1.37`, plus the approved KC-P-041 replication specification; a same-state old runtime screenshot is unavailable.
- Implementation screenshots: `docs/features/profile_settings/feature_profile_center/pages/page_edit_profile/android_edit_profile_v2.png`, `android_edit_profile_bottom_v2.png` and `android_edit_profile_aligned_v2.png`.
- Viewport: Android Medium Phone, `1080 × 2400`; platform status and home chrome excluded from app-owned layout judgment.

## Verified result

- The old black canvas, warm-gold centered title, left return key, empty centered avatar, thin dividers and two-column information rows are retained.
- All approved public fields and preference rows are scroll-reachable; the bottom save action remains clear of Android navigation.
- Long-pressing the title exposes repeatable Fake conflict, unknown-result, save-error, catalog-expiry and session-invalid states without adding permanent debug chrome.
- Avatar cancellation/permission/upload failure, field validation, unsaved-return confirmation, single-flight save and 200% text scaling are covered without real media or server access.
- The user-identified alignment defect is corrected: right-side values use the remaining width and every chevron occupies the same fixed `24dp` column. The settings page uses the same rule.
- `flutter analyze` is clean; 11 focused edit/alignment tests and the full 132-test suite pass.

## Remaining blocker

- [P2] Exact old-runtime pixel fidelity cannot be certified until a matching archived `pages/myinfo/myinfo` screenshot is available for normalized side-by-side comparison.

final result: blocked

---

# Design QA — Legacy Asset Ledger

- source visual truth path: old Mini Program `C:\Users\Poplar\Desktop\KingClub-app\pages\mybalance\mybalance.wxml` and `mybalance.wxss` at `master / 505d222 / 1.1.37`; no same-state full old-runtime screenshot is available
- implementation screenshots:
  - `docs/features/membership_wallet/feature_asset_ledger/pages/page_asset_ledger/screenshots/android_asset_ledger_v2.png`
  - `docs/features/membership_wallet/feature_asset_ledger/pages/page_asset_ledger/screenshots/android_asset_ledger_gold_v2.png`
- source pixels / CSS size / density: unavailable because the old runtime image is missing
- implementation pixels: `1080 × 2400`; Android API 37 emulator; native device-density capture; logical viewport approximately `411 × 891`
- states: balance ledger and gold-coin ledger
- normalization: Android status/navigation chrome was excluded from app-owned layout judgment; exact density normalization against the old Mini Program is impossible without a runtime capture

## Full-view comparison evidence

- The implementation retains the visible old source structure: `#0e090c` canvas, centered “账单记录” title, equal asset tabs, gold selection underline, left year selector, right income/expense summary and compact full-width ledger rows.
- The old order tab is intentionally absent under the approved product boundary; V2 adds three independent authoritative summary cards above the legacy tabs without displaying a cross-unit total.
- The final Android captures show all three cards, tabs, period summary, rows, amounts and footer without overflow, clipping or system-navigation collision.
- A same-state source/implementation image pair cannot be composed because the old WXML/WXSS is structural evidence rather than a rendered source image.

## Focused comparison evidence

- Fonts and typography: the centered title, larger selected tab, compact row title/time and right-aligned large amount preserve the old hierarchy; exact Mini Program font rasterization remains unverified.
- Spacing and layout rhythm: equal summary cards, 48dp tab strip, 64dp period row, circular leading icons and low-opacity dividers create the same dense vertical rhythm without cramped text.
- Colors and visual tokens: background `#0e090c`, muted `#CCC` text, translucent white metadata/dividers and `#ffb400` positive/selected emphasis map directly to the old stylesheet.
- Image quality and asset fidelity: the existing legacy gold and diamond raster assets are reused directly and remain sharp; the balance symbol and state controls use one Material icon family because no matching old balance raster exists.
- Copy and content: each entry pairs sign with “已入账/处理中/已冲正/状态更新中”; the page omits all out-of-scope write actions and does not expose technical refs.
- Icons and states: balance, coin and diamond states have consistent optical size; summary failure, empty, offline, pagination failure and session reset retain practical tap targets and safe recovery.

## Findings

- [P2] Exact old-runtime pixel fidelity remains blocked.
  - Location: complete `mybalance`-derived asset ledger.
  - Evidence: final balance and coin implementation captures exist, but no same-state old Mini Program screenshot can be placed beside them.
  - Impact: structure, palette, density, assets, content and Android rendering are verified, but subtle rpx-to-dp spacing and font metrics cannot be certified pixel-accurate.
  - Fix: capture the archived old `mybalance` balance and coin states at a known viewport, normalize the app-owned regions and rerun the side-by-side comparison.

## Comparison history

- Pass 1: the first Android render exposed a P2 horizontal crop—the third summary card extended beyond the right edge.
- Fix: replaced the horizontally scrolling fixed-width summary cards with one responsive equal-width row and added scale-down protection for values.
- Pass 2 evidence: `android_asset_ledger_v2.png` and `android_asset_ledger_gold_v2.png` show all three cards fully inside the `1080 × 2400` viewport with no text or icon collision.
- Pass 3: the user identified that the return control was absent. The header `SizedBox` had no explicit width, so its `Stack` collapsed to the centered title and clipped both positioned side controls.
- Fix: the header now uses `width: double.infinity`; final balance and coin captures show the return control and right-side `UI MOCK` marker inside the viewport, while a dedicated widget test verifies the return callback.
- Source-fidelity remains blocked solely by the missing same-state old runtime image.

## Implementation checklist

- [x] Old black-brown ledger structure and gold selection treatment
- [x] Separate balance, coin and diamond summaries with no total
- [x] Stable year filter, refresh, cursor append and retry
- [x] Pending, reversed, frozen, offline, unknown and session-invalid states
- [x] Ordinary in-page expansion and opaque order navigation
- [x] No recharge, withdrawal, transfer, exchange or payment allocation
- [x] Android balance and coin evidence captures
- [x] Thirteen dedicated asset-ledger tests, including visible/clickable back navigation
- [x] `flutter analyze` clean and full Flutter suite: 121 tests passed
- [ ] Same-state old Mini Program screenshot and normalized side-by-side comparison

## Follow-up Polish

- Tune only exact Mini Program font metrics and rpx spacing after an equivalent old-runtime capture becomes available.

final result: blocked

---

# Design QA — Legacy Payment Processing and Result

- source visual truth path: old Mini Program `C:\Users\Poplar\Desktop\KingClub-app\pages\pay\pay.wxml`, `pay.wxss`, `pages\success\success.wxml`, `success.wxss` and the original `images\success2.png` / `images\WEIPAY.png` assets at `master / 505d222 / 1.1.37`; no same-state full old-runtime screenshot is available
- implementation screenshots:
  - `docs/features/commerce/feature_payment/pages/page_payment_result/screenshots/android_payment_ready_v2.png`
  - `docs/features/commerce/feature_payment/pages/page_payment_result/screenshots/android_payment_verifying_v2.png`
  - `docs/features/commerce/feature_payment/pages/page_payment_result/screenshots/android_payment_succeeded_v2.png`
  - `docs/features/commerce/feature_payment/pages/page_payment_result/screenshots/android_payment_pending_v2.png`
  - `docs/features/commerce/feature_payment/pages/page_payment_result/screenshots/android_payment_scenarios_v2.png`
- source pixels / CSS size / density: unavailable because the old same-state runtime image is missing
- implementation pixels: `1080 × 2400`; Android API 37 emulator; native device-density capture; logical viewport approximately `411 × 891`
- states: ready, Fake attempt verification, server-confirmed success, result pending and scenario selector
- normalization: Android status/navigation chrome was excluded from app-owned layout judgment; exact source-density normalization was impossible without an old runtime capture

## Full-view comparison evidence

- The implementation follows the old `pay` / `success` centered composition: black canvas, concise centered state graphic and copy, bottom action area and `SHANGHAI · ZHUZHOU` footer.
- The preparation screen extends that visual language with the approved black radial background, authoritative beige amount card and a compact payment-method list; this state has no equivalent old full-screen image.
- The original legacy success mark and WeChat-pay raster asset are reused directly rather than redrawn or replaced with a generic placeholder.
- All five Android captures retain readable content and reachable persistent actions without overflow, clipping or collision with system navigation.
- A valid source/implementation side-by-side pixel comparison cannot be produced because WXML/WXSS and isolated assets are structural evidence, not a same-state source screenshot.

## Focused comparison evidence

- Fonts and typography: centered result titles, restrained secondary copy, large authoritative amount and compact method labels retain the old hierarchy without truncation; exact Mini Program font rasterization remains unverified.
- Spacing and layout rhythm: the centered result group, generous black negative space, fixed bottom actions and footer reproduce the old result rhythm; the ready state uses consistent card padding, separators and practical tap targets.
- Colors and visual tokens: black, dark brown, champagne beige and muted gold map to the old payment/result palette; green is limited to the original WeChat asset and confirmed-success semantics.
- Image quality and asset fidelity: `success2.png` and `WEIPAY.png` are copied from the stable old project and render sharply with their original transparency; non-source abnormal-state symbols use one consistent Material icon family.
- Copy and content: the page distinguishes provider return from server confirmation, never labels pending/unknown as success, and clearly states that the current path uses Fake data without a real SDK.
- Icons and states: ready, verifying, succeeded, cancelled, failed, pending, expired, order-changed, offline, method-unavailable, session-invalid and zero-amount states have distinct feedback and safe actions.

## Findings

- [P2] Exact old-runtime pixel fidelity remains blocked.
  - Location: complete payment preparation and result flow.
  - Evidence: five `1080 × 2400` implementation captures and original source assets exist, but there is no same-state old Mini Program full-screen screenshot to place beside them.
  - Impact: device layout, source assets, state hierarchy and interactions are verified, but subtle rpx-to-dp spacing, font metrics and original runtime placement cannot be certified pixel-accurate.
  - Fix: capture the archived old payment and success states at a known viewport, normalize the app-owned regions, then rerun side-by-side comparison and resolve any visible P1/P2 drift.

## Comparison history

- Pass 1: reviewed ready, verifying, succeeded, pending and scenario-selector Android captures. No P0/P1/P2 implementation-layout issue, broken asset, clipped action or footer collision was found.
- No source-fidelity fix iteration is claimed because the required same-state old runtime capture is unavailable.

## Implementation checklist

- [x] Fake authoritative amount and service-available payment methods
- [x] One-attempt-only handoff and busy-return warning
- [x] Provider result always followed by Fake server reconciliation
- [x] Success displayed only after Fake server `SUCCEEDED`
- [x] Cancel, fail, pending, unknown, late success and safe-retry recovery
- [x] Expired, order-changed, offline, unavailable-method and session-invalid blocking states
- [x] Zero-amount confirmation without a payment attempt
- [x] Original old success and WeChat payment assets
- [x] Android five-state evidence captures
- [x] `flutter analyze` clean
- [x] Twelve dedicated payment tests
- [x] Full Flutter suite: 108 tests passed
- [ ] Same-state old Mini Program screenshot and normalized side-by-side comparison

## Follow-up Polish

- Revisit only pixel-level spacing and font tuning after equivalent old-runtime captures become available; do not weaken the server-confirmed success rule for visual parity.

final result: blocked

---

# Design QA — Legacy Unified Order Center

- source visual truth path: old Mini Program `C:\Users\Poplar\Desktop\KingClub-app\pages\mybalance`, `pages\shoping3`, `pages\order`, `pages\order-manage` and `pages\detail-order` at `master / 505d222 / 1.1.37`; no same-state unified order-center runtime screenshot exists
- implementation screenshots:
  - `docs/features/commerce/feature_order_center/pages/page_order_center/screenshots/android_order_center_v2.png`
  - `docs/features/commerce/feature_order_center/pages/page_order_center/screenshots/android_order_center_pending_v2.png`
- source pixels / CSS size / density: unavailable because the old product has no unified screen to capture
- implementation pixels: `1080 × 2400`; Android API 37 emulator; native device-density capture; logical viewport approximately `411 × 891`
- state: mixed all-orders projection and pending-payment filter
- normalization: Android status and home chrome were excluded from app-owned layout judgment; exact source-density normalization was impossible without a matching old runtime image

## Full-view comparison evidence

- The implementation combines the visible old `mybalance` black canvas, horizontal gold-selected category rhythm and dense rows with the brown/gold order hierarchy from `shoping3`.
- Four heterogeneous Fake orders remain readable in one viewport, and the pending-payment filter reduces the projection to the matching order without moving or resizing the global header.
- No overflow, clipped card, hidden amount, broken image or system-navigation collision is visible in either Android capture.
- A valid source/implementation side-by-side pixel comparison cannot be produced because the old client contains only separate balance, product-order and management screens rather than this approved consolidated state.

## Focused comparison evidence

- Fonts and typography: bold order names, large gold amounts, secondary gray timestamps and compact type/status labels have a clear hierarchy with no truncation; exact old runtime font metrics remain unverified.
- Spacing and layout rhythm: the fixed header, four equal-width filters, narrow gold underline, dense rounded cards and consistent image/text/action columns preserve the old list cadence.
- Colors and visual tokens: black canvas, near-black brown cards, champagne text, gold accents and semantic status dots are consistent with the old commerce surfaces.
- Image quality and asset fidelity: local high-resolution champagne, whisky and fruit assets remain sharp at the final crop; the old remote catalog images are unavailable and therefore not claimed as exact matches.
- Copy and content: each row exposes order type, title, summary, time, status, amount and one safe detail action. Approved filter labels and mixed business types are complete.

## Findings

- [P2] Exact old-runtime visual fidelity is blocked.
  - Location: complete unified order-center screen.
  - Evidence: two `1080 × 2400` implementation captures exist, but no old unified order-center screenshot can be placed beside them; the source functionality was scattered across multiple pages.
  - Impact: layout quality, content hierarchy, interactions and Android rendering are verified, but subtle spacing, font and asset differences cannot be certified pixel-accurate.
  - Fix: if an archived old unified-order build or target mock becomes available, capture the same two states and run a normalized comparison before changing the present visual baseline.

## Comparison history

- Pass 1: captured mixed all-orders and pending-payment states. No P0/P1 implementation defect, overflow, clipped control, broken asset or card-density problem was found.
- No source-fidelity fix iteration is claimed because the required same-state old runtime visual does not exist.

## Implementation checklist

- [x] Old black/brown/gold unified commerce styling
- [x] Mixed AA, VIP and scan-order Fake projections
- [x] Four status filters
- [x] Refresh, cursor pagination, retry and end-of-list behavior
- [x] Offline cache, unknown status, empty, error and session-invalid states
- [x] Opaque `OrderRef` detail intent only
- [x] Android default and filtered captures
- [x] `flutter analyze` clean
- [x] Seven dedicated order-center tests
- [x] Full Flutter suite: 87 tests passed
- [ ] Same-state old runtime image and normalized side-by-side comparison

## Follow-up Polish

- Replace local Fake catalog images only after the production order projection supplies authoritative image URLs and crops.

final result: blocked

---

# Design QA — Legacy Scan Ordering Cart

- source visual truth path: old Mini Program `C:\Users\Poplar\Desktop\KingClub-app\pages\shoping\shoping.wxml` and `shoping.wxss` at `master / 505d222 / 1.1.37`; no same-state old runtime screenshot is available
- implementation screenshots:
  - `docs/features/commerce/feature_scan_ordering/pages/page_scan_ordering_cart/screenshots/android_scan_ordering_cart_v2.png`
  - `docs/features/commerce/feature_scan_ordering/pages/page_scan_ordering_cart/screenshots/android_scan_ordering_bag_v2.png`
- source pixels / CSS size / density: unavailable because source runtime visual is missing
- implementation pixels: `1080 × 2400`; Android API 37 emulator; native device-density capture; logical app viewport approximately `411 × 891`
- state: validated Fake V8 table context; alcohol catalog; empty cart and two-item expanded cart
- normalization: platform status/home chrome excluded from app-owned layout review; exact density normalization against the old runtime could not be performed

## Full-view comparison evidence

- The implementation visibly reproduces the old `shoping` composition: black canvas, rounded search header, KingBar store/table block, three horizontal top categories, narrow left subcategory rail, photographic product rows, orange-gold pricing and a fixed shopping-bag footer.
- The expanded cart preserves the old brown-gold header, dark line-item list, quantity controls, clear action and bottom estimate hierarchy.
- The Android captures show no overflow, clipped product controls, hidden cart action or system-navigation collision.
- A valid source/implementation side-by-side visual comparison cannot be produced because WXML/WXSS is structural evidence rather than a source image.

## Focused comparison evidence

- Fonts and typography: compact Chinese labels, strong product names, muted specifications, orange-gold price emphasis and strikethrough list prices are legible and do not wrap incorrectly; exact old font metrics remain unverified.
- Spacing and layout rhythm: the top category rail, `82dp` left category column, product image/text split and fixed `74dp` cart bar create the same dense ordering rhythm visible in the old source; no persistent control is covered.
- Colors and visual tokens: black, `#C9B69E` legacy gold, `#FFB400` price/action gold, brown table capsule and `#94826C` cart header map directly to the old palette.
- Image quality and asset fidelity: three high-resolution local Fake product photographs are used with consistent black/gold lighting and sharp crops; no generic placeholder, emoji or drawn substitute is visible. Exact old server-hosted product photos were unavailable.
- Copy and content: store, table, categories, specifications, prices, estimate warning and cart actions are complete. “预估” and the Fake Quote explanation are deliberate safety additions for the no-server UI stage.

## Findings

- [P2] Exact old-runtime visual fidelity remains blocked.
  - Location: complete scan-ordering catalog and expanded shopping bag.
  - Evidence: two `1080 × 2400` implementation captures exist, but no same-state old Mini Program `shoping` screenshot can be opened and placed beside them; source WXML/WXSS alone does not satisfy the visual comparison gate.
  - Impact: layout, interactions and device rendering are verified, but subtle rpx-to-dp spacing, font and server-image differences cannot be classified as pixel-accurate.
  - Fix: capture the old `shoping` catalog and expanded cart with the same category/cart state, normalize both to the app-owned viewport, then resolve any visible P1/P2 differences.

## Comparison history

- Pass 1: captured the Android empty-cart catalog and two-item expanded cart. No implementation overflow, clipped control, broken asset or bottom obstruction was found.
- No source-fidelity fix iteration is claimed because the required old runtime visual is unavailable.

## Implementation checklist

- [x] Old black/gold store and table header
- [x] Search, top category and left subcategory navigation
- [x] Real local product imagery and product quantity controls
- [x] Sold-out, limit, offline, invalid-context, closed, empty and catalog-error Fake states
- [x] Expanded shopping bag and guarded clear action
- [x] Estimate-only total and typed Fake Quote intent
- [x] Android default and expanded-cart captures
- [x] Static analysis and five dedicated ordering tests
- [x] Full Flutter suite: 75 tests passed
- [ ] Same-state old Mini Program screenshots and normalized side-by-side comparison

## Follow-up Polish

- Replace local Fake product photography only when the approved server catalog supplies the production image set; keep the current crops for UI Mock acceptance.

final result: blocked

---

# Design QA — Legacy Admission Ticket

- source visual truth: old Mini Program source `KingClub-app/pages/ticket` at `master / 505d222 / 1.1.37`
- implementation screenshots:
  - `docs/features/club/feature_admission_ticket/pages/page_admission_ticket/android_admission_ready_v2.png`
  - `docs/features/club/feature_admission_ticket/pages/page_admission_ticket/android_admission_checked_in_v2.png`
  - `docs/features/club/feature_admission_ticket/pages/page_admission_ticket/android_admission_scenarios_v2.png`
- source pixels: unavailable; no same-state old runtime screenshot
- implementation pixels: `1080 × 2400`; Android API 37 emulator; native device-density capture
- states: ready dynamic code, not-yet-open, checked-in stamp, exit confirmation, reentry, ended, revoked, offline and privacy-covered

## Full-view and focused evidence

- Full-view ready capture preserves the old deep-red radial canvas, centered `POSITIONING CARD`, rounded purple/magenta ticket, pink square code area and English rules block.
- Focused checked-in capture preserves the old tilted pink “已入场” stamp while correctly hiding the reusable code.
- Scenario capture shows that all Fake variants remain inside the same visual shell.
- Exact side-by-side pixel comparison is unavailable because the old page has no runtime screenshot; WXML/WXSS is structural evidence only.

## Required fidelity surfaces

- Typography: uppercase title tracking, large table label, scene time, package summary and small instruction hierarchy follow the old source; exact font metrics remain unverified.
- Spacing/layout: final Android captures show clear edge controls, centered title, stable ticket proportions, readable QR size and no clipped content.
- Colors/tokens: old `#470f24 / #12020c / #ad016a / #5a1e80 / #fbafda` palette is reproduced directly.
- Image quality/assets: the QR is generated by a standard QR library from a local Fake opaque token; no placeholder or permanent member code is shown.
- Copy/content: permanent member ID, price and other members are removed by the approved privacy boundary; venue, scene, package, state and assistance text remain.

## Findings

- [P2] Pixel fidelity cannot pass until a same-state old `ticket` runtime screenshot is available for normalized comparison.
- No further P0/P1/P2 implementation defect is visible in the final Android captures.

## Comparison history

- Initial ready-state capture exposed overlapping back/help controls because the header Stack shrink-wrapped to its title.
- The header was expanded to full width; the revised `android_admission_ready_v2.png` shows both edge controls separated from the centered title.

## Verification

- [x] Three Android captures at `1080 × 2400`
- [x] Five dedicated admission widget flows
- [x] Full Flutter suite: 70 tests passed
- [x] `flutter analyze`: no issues
- [ ] Same-state old Mini Program screenshot and normalized pixel comparison

final result: blocked

---

# Design QA — Legacy VIP Party Host Management

- source visual truth: old Mini Program source `KingClub-app/pages/order-manage` at `master / 505d222 / 1.1.37`
- implementation screenshots:
  - `docs/features/club/feature_vip_party/pages/page_vip_party_management/android_vip_manage_overview_v2.png`
  - `docs/features/club/feature_vip_party/pages/page_vip_party_management/android_vip_manage_members_v2.png`
  - `docs/features/club/feature_vip_party/pages/page_vip_party_management/android_vip_manage_revoke_confirm_v2.png`
  - `docs/features/club/feature_vip_party/pages/page_vip_party_management/android_vip_manage_invite_v2.png`
- source pixels: unavailable; no same-state old runtime screenshot
- implementation pixels: `1080 × 2400`; Android API 37 emulator; native device density capture
- states: overview, read-only bill, members and invitations, revoke confirmation, single-friend selector, recruiting toggle, offline, locked, version-conflict and permission-lost

## Full-view and focused evidence

- Full-view implementation preserves the old centered card-seat title, black/brown radial canvas, three equal “概况 / 账单 / 成员” tabs, gold underline, low-opacity dividers and dense consumer-order hierarchy.
- Focused member capture confirms the old avatar/name/status/right-action rhythm without the unsafe “踢人” action.
- Focused invite capture confirms a single-friend selector rather than group sharing; the revoke confirmation explains that only an unaccepted invitation is affected.
- Exact side-by-side image comparison could not be produced because the source page has no same-state runtime screenshot; source WXML/WXSS is structural evidence, not valid pixel evidence.

## Required fidelity surfaces

- Typography: weights and hierarchy are consistent with the existing Flutter legacy replica; exact old font metrics remain unverified without a source capture.
- Spacing/layout: Android captures show no overflow, clipped row action, hidden tab or bottom collision.
- Colors/tokens: existing `legacyGold`, `legacyPink` and black/brown surfaces are used consistently; exact source sampling remains unavailable.
- Image quality/assets: this management state contains no old custom raster content; supplied Material person/gender icons are standard UI icons, not replacements for a brand asset.
- Copy/content: consumer host details, bill summary and member states are complete; employee status, service assignment,商品确认 and paid-member removal are intentionally excluded by the approved product boundary.

## Findings

- [P2] Pixel fidelity cannot be passed until a same-state runtime screenshot of the old `order-manage` page is available for a normalized side-by-side comparison.
- No additional P0/P1/P2 implementation defect is visible in the four Android captures.

## Comparison history

- Initial Android capture showed the overview and member list without overflow or clipped content; no implementation visual fix was required after capture.
- Functional test feedback found an undersized Fake scenario sheet and an ambiguous test target; the sheet was changed to a constrained scrollable list and all tests were rerun successfully. This was runtime robustness, not a source-fidelity comparison iteration.

## Verification

- [x] Four Android captures at `1080 × 2400`
- [x] Invite, revoke, release-unpaid-hold, recruitment and read-only Fake interactions
- [x] Full Flutter suite: 65 tests passed
- [x] `flutter analyze`: no issues
- [ ] Same-state old Mini Program screenshot and normalized pixel comparison

final result: blocked

---

# Design QA — Legacy VIP Party Create

- source visual truth: old Mini Program source `KingClub-app/pages/vip-order` at `master / 505d222 / 1.1.37`
- implementation screenshots:
  - `docs/features/club/feature_vip_party/pages/page_vip_party_create/android_vip_create_legacy_replica_v2.png`
  - `docs/features/club/feature_vip_party/pages/page_vip_party_create/android_vip_create_rules_v2.png`
  - `docs/features/club/feature_vip_party/pages/page_vip_party_create/android_vip_create_ready_v2.png`
  - `docs/features/club/feature_vip_party/pages/page_vip_party_create/android_vip_create_pending_payment_v2.png`
- implementation pixels: `1080 × 2400`; Android API 37 emulator, approximately `411 × 891` logical px
- state: default quote, scrolled rules, creation enabled and paid Fake result
- normalization: Android platform status/home chrome excluded; app-owned content reviewed at the same emulator viewport

## Full-view comparison evidence

- The Android implementation follows the old source hierarchy: centered black/gold header, translucent grouped rows, reservation date, table, people, package, price, switch groups and fixed champagne footer.
- App-owned UI intentionally omits the WeChat capsule and removes the old appearance, age, gender-ratio and optional-host controls approved out of V2.
- The form scrolls behind a persistent footer without hiding the rule checkbox or primary action. A paid submission produces only a Fake pending-payment intent and never claims payment success.

## Required fidelity surfaces

- Fonts and typography: compact Chinese labels, gold value hierarchy, bold selector values and large footer amount render without clipping or unintended wrapping.
- Spacing and layout rhythm: old row order and grouped separators are preserved; the fixed footer remains clear of Android's home indicator.
- Colors and visual tokens: radial black/brown canvas, `#C9B69E` gold, amber price, translucent selection blocks and champagne footer match the existing legacy replica system.
- Image quality and asset fidelity: this source state contains no required photographic or branded raster asset; selector arrows and switches use the nearest Material platform icons/controls rather than drawn placeholders.
- Copy and content: old labels are retained where the behavior remains; removed unsafe controls are not exposed. New rule and result copy explicitly distinguishes Fake data from real payment.

## Findings

- [P2] Final same-state pixel comparison is blocked.
  - Location: complete `vip-order` create screen.
  - Evidence: Android implementation screenshots exist, but no old Mini Program runtime screenshot for the same form state is available; WXML/WXSS is not a visual artifact sufficient for a pixel-pass claim.
  - Impact: hierarchy, behavior and device layout are verified, but small font, opacity and rpx-to-dp differences cannot yet be classified as 1:1.
  - Fix: capture the old `vip-order` page with matching table/package/people state, normalize to the Android app-owned viewport, compare side by side and resolve remaining P1/P2 drift.

## Comparison history

- Pass 1: captured the default top, scrolled rules, enabled primary action and pending-payment result on Android. No overflow, clipped field, footer collision or broken control was found.
- No source-runtime comparison iteration is claimed because the required old same-state screenshot is unavailable.

## Implementation checklist

- [x] Legacy field order and grouped black/gold form
- [x] Table, people and package selectors with Fake re-quote
- [x] Members-pay/host-sponsored and public/invite-only mappings
- [x] Terms reset after quote-affecting changes
- [x] Quote changed, expired, inventory, offline and result-unknown states
- [x] Paid pending-payment and zero-cash confirmation boundaries
- [x] Typed route from VIP browse page
- [x] Static analysis and widget flow tests
- [ ] Same-state old Mini Program runtime screenshot and final pixel comparison

final result: blocked

---

# Design QA — Legacy VIP Party Browse

- source visual truth: old Mini Program source `KingClub-app/pages/Choose2` at `master / 505d222 / 1.1.37`
- implementation screenshots:
  - `docs/features/club/feature_vip_party/pages/page_vip_party_detail/android_vip_legacy_replica_v2.png`
  - `docs/features/club/feature_vip_party/pages/page_vip_party_detail/android_vip_host_expanded_v2.png`
  - `docs/features/club/feature_vip_party/pages/page_vip_party_detail/android_vip_viewer_expanded_v2.png`
  - `docs/features/club/feature_vip_party/pages/page_vip_party_detail/android_vip_join_confirm_v2.png`
  - `docs/features/club/feature_vip_party/pages/page_vip_party_detail/android_vip_pending_payment_v2.png`
- implementation pixels: `1080 × 2400`; Android API 37 emulator

## Verified implementation

- The page keeps the old radial black/gold canvas, date strip, new-seat card, large table label, occupancy grid, package/price/QR hierarchy and inline magenta member section.
- The permanent `UI MOCK` label is removed; App-owned content does not reproduce the WeChat capsule.
- Host empty slots expose only a controlled Fake invite, while a public viewer sees safe member placeholders and one join action.
- Paid join creates a Fake pending-payment intent and explicitly does not charge; host-sponsored join confirms a local zero-cash seat without opening payment.
- Empty, offline and full states preserve date/list context and do not expose invalid write actions.

## Findings

- [P2] Final same-state pixel comparison is blocked because a runtime screenshot from the old `Choose2` page is not available; source WXML/WXSS and existing V2 captures are sufficient for structural verification, not a pixel-pass claim.
- Device captures show no overflow, clipped action or broken return path at `1080 × 2400`.

## Verification

- [x] Android device capture at `1080 × 2400`
- [x] Four focused VIP widget flows
- [x] Full widget suite: 55 tests passed
- [x] `flutter analyze`: no issues
- [ ] Same-state old Mini Program runtime screenshot and final pixel comparison

final result: blocked

---

# Design QA — Legacy AA Reservation Batch

- source visual truth: old Mini Program sources `KingClub-app/pages/Choose`, `pages/order`, `pages/order2` plus the previously captured Android landing screenshot
- implementation screenshots:
  - `docs/features/club/feature_aa_reservation/pages/page_aa_reservations/android_aa_legacy_replica_v2.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_package_detail/android_aa_package_legacy_replica_v2.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_confirmation_legacy_replica_v2.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_fake_pending_payment.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_reservations/android_aa_pending_payment.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_reservations/android_aa_confirmed.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_reservations/android_aa_sold_out.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_reservations/android_aa_offline.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_quote_expired.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_submission_sold_out.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_submission_duplicate.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_submission_result_unknown.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_confirmation_ineligible.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_confirmation_offline.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_confirmation_session_invalid.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_initial_loading.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_requote_loading.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_quote_changed.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_invalid_ref.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_zero_cash.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_order_confirmation/android_aa_zero_cash_confirmed.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_package_detail/android_aa_package_price_updated.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_package_detail/android_aa_package_price_acknowledged.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_package_detail/android_aa_package_sold_out.png`
  - `docs/features/club/feature_aa_reservation/pages/page_aa_reservations/android_aa_no_recommendation.png`
- implementation pixels: `1080 × 2400`; Android API 37 emulator
- states: available landing, pending payment, confirmed reservation, sold out, offline cache, no recommendation, default/price-updated/sold-out package detail, default confirmation quote, initial loading, requote loading/changed, expired/invalid quote, zero-cash confirmation, submit-time sold out, duplicate active reservation, unknown submission result, ineligible submission, offline confirmation and session-invalid reset

## Verified implementation

- The landing page keeps the old black/gold radial canvas, horizontal date selector, no-reservation card, long rule block, gold package cards, sold-out gray state and one-person notice.
- The package page restores the old `POSITIONING CARD` hierarchy, centered seat/date/package content and fixed white-to-gold footer with the pink “抢订” action.
- The confirmation page restores the old black-red grouped rows and pink payment footer while replacing unsafe free-form asset calculation with Fake server-style deduction options.
- The complete local path is functional: package join → detail → confirmation → deduction requote → terms confirmation → Fake pending-payment result.
- Existing pending/confirmed reservations lock same-day package entry; sold-out and offline states remain readable without exposing a write action. The offline refresh restores the default Fake projection.
- Expired quote visibly blocks deductions, terms and payment until a local Fake refresh clears the warning and requires rule confirmation again.
- Package refresh can now produce a changed price or sold-out result. A changed price requires a separate acknowledgement before the updated Fake amount reaches confirmation; sold out only returns to the list. “No recommendation” disables only the recommendation action and keeps manual package selection available.
- Confirmation submission now keeps three critical abnormal results visible in-page: sudden sold out explicitly creates nothing and charges nothing; a duplicate shows the existing Fake order; an unknown result blocks duplicate submission and reconciles the same Fake request into one pending-payment result.
- The remaining confirmation failures are also complete: eligibility loss exits the write path without an order or charge, offline keeps the quote read-only until local recovery, and session invalid removes every quote/payment surface before emitting the global mobile-login reset intent.
- Initial loading now withholds stale amounts, requote keeps the old amount until the replacement is ready, invalid references clear the complete business surface, and a zero-cash reservation uses a confirmation path that never claims or opens payment.
- App-owned screens omit the WeChat capsule and do not call the super interface, WebSocket or payment SDK.

## Findings

- [P2] Pixel-level old-runtime comparison is blocked because the old Mini Program same-state screenshots could not be captured; Windows Computer Use was unavailable during this pass.
- Device screenshots show no overflow, missing return path, broken asset or bottom-footer collision after fixing the themed button's infinite-width constraint.

## Verification

- [x] Android device capture at `1080 × 2400`
- [x] KingTheme-specific three-page widget flow
- [x] Full widget suite: 55 tests passed
- [x] `flutter analyze`: no issues
- [ ] Same-state old Mini Program runtime screenshots and final pixel comparison

final result: blocked

---

# Design QA — Legacy Scan Order Confirmation

- source visual truth path: old Mini Program `C:\Users\Poplar\Desktop\KingClub-app\pages\shoping2\shoping2.wxml` and `shoping2.wxss` at `master / 505d222 / 1.1.37`; no same-state old runtime screenshot is available
- implementation screenshots:
  - `docs/features/commerce/feature_scan_ordering/pages/page_scan_order_confirmation/screenshots/android_order_confirmation_v2.png`
  - `docs/features/commerce/feature_scan_ordering/pages/page_scan_order_confirmation/screenshots/android_order_confirmation_details_v2.png`
  - `docs/features/commerce/feature_scan_ordering/pages/page_scan_order_confirmation/screenshots/android_order_created_fake_v2.png`
- source pixels / CSS size / density: unavailable because the old runtime visual is missing
- implementation pixels: `1080 × 2400`; Android API 37 emulator; native device-density capture; logical viewport approximately `411 × 891`
- state: ready Fake Quote, scrolled pricing/payment explanation, and created Fake pending-payment order
- normalization: platform status/home chrome excluded from app-owned layout review; exact density normalization against the old runtime could not be performed

## Full-view comparison evidence

- The implementation reproduces the old `shoping2` structure visible in source: radial black/brown canvas, centered gold title, stacked brown-gold rounded cards, dense product rows, price summary and fixed bottom amount/action bar.
- Product imagery, names, specifications, unit prices, quantities and subtotals remain readable at the Android viewport; scrolling exposes the complete authoritative quote and payment explanation without hiding the persistent actions.
- The primary action intentionally reads “提交订单” instead of the unsafe old “立即支付”. The result sheet says only that a Fake pending-payment order was created.
- A valid source/implementation side-by-side pixel comparison cannot be produced because WXML/WXSS is structural evidence rather than a source image.

## Focused comparison evidence

- Fonts and typography: compact Chinese labels, bold product names, large subtotals and a strong bottom amount hierarchy render without truncation; exact old font metrics remain unverified.
- Spacing and layout rhythm: stacked `8dp` cards, dense product rows, narrow dividers and the fixed `82dp` footer preserve the old page rhythm; no footer collision or clipped control is visible.
- Colors and visual tokens: `#C9B69E` card/gold, `#181205` card text, black gradient footer and brown radial canvas map directly to the old stylesheet.
- Image quality and asset fidelity: the same high-resolution local Fake champagne and whisky photographs used by KC-P-034 are retained with sharp crops and consistent black/gold lighting; the old remote server images were unavailable.
- Copy and content: table, store, quote countdown, products, discount and amount are complete. Wallet/coin/coupon inputs are intentionally replaced with the approved read-only “订单创建后选择” explanation.

## Findings

- [P2] Exact old-runtime visual fidelity remains blocked.
  - Location: complete `shoping2` confirmation screen.
  - Evidence: three `1080 × 2400` implementation captures exist, but no same-state old Mini Program screenshot can be placed beside them; source WXML/WXSS alone does not satisfy the visual comparison gate.
  - Impact: layout, copy, interactions and device rendering are verified, but subtle rpx-to-dp spacing, font and remote-image differences cannot be classified as pixel-accurate.
  - Fix: capture the old `shoping2` page with the same products and price state, normalize both app-owned viewports, then resolve any visible P1/P2 differences.

## Comparison history

- Pass 1: captured the ready top, scrolled quote/payment section and created-order result. No overflow, clipped control, broken image or system-navigation collision was found.
- No source-fidelity fix iteration is claimed because the required old runtime visual is unavailable.

## Implementation checklist

- [x] Old brown-gold order information and product cards
- [x] Quote countdown and explicit price hierarchy
- [x] Removed client-entered wallet, coin and coupon allocation
- [x] Price-change acknowledgement and expired-quote refresh
- [x] Sold-out, limit, offline and session-invalid blocking states
- [x] Stable Fake submission and result-unknown reconciliation
- [x] Fake pending-payment result without payment-success claim
- [x] Android ready, details and result captures
- [x] Static analysis and five dedicated confirmation tests
- [x] Full Flutter suite: 80 tests passed
- [ ] Same-state old Mini Program screenshot and normalized side-by-side comparison

## Follow-up Polish

- Replace the local Fake product photographs only after the approved production catalog supplies authoritative image URLs and crops.

final result: blocked

---

# Design QA — Legacy Unified Order Detail

- source visual truth path: old Mini Program `C:\Users\Poplar\Desktop\KingClub-app\pages\shoping3\shoping3.wxml`, `shoping3.wxss`, `pages\detail-order\detail-order.wxml` and `detail-order.wxss` at `master / 505d222 / 1.1.37`; no same-state unified consumer-order-detail runtime screenshot exists
- implementation screenshots:
  - `docs/features/commerce/feature_order_center/pages/page_order_detail/screenshots/android_order_detail_v2.png`
  - `docs/features/commerce/feature_order_center/pages/page_order_detail/screenshots/android_order_detail_scrolled_v2.png`
  - `docs/features/commerce/feature_order_center/pages/page_order_detail/screenshots/android_order_detail_confirmed_v2.png`
  - `docs/features/commerce/feature_order_center/pages/page_order_detail/screenshots/android_order_detail_scenarios_v2.png`
- source pixels / CSS size / density: unavailable because the old runtime image is missing
- implementation pixels: `1080 × 2400`; Android API 37 emulator; native device-density capture; logical viewport approximately `411 × 891`
- states: waiting-payment top, scrolled products/amount/timeline, confirmed admission state and Fake scenario selector
- normalization: Android system status/home chrome excluded from app-owned layout judgment; no exact source-density normalization was possible

## Full-view comparison evidence

- The implementation preserves the old `shoping3` radial black/brown canvas, centered champagne title, pale brown-gold grouped cards, dark text, compact rows and product-detail hierarchy.
- The status summary and chronological progress extend `detail-order`'s vertical information rhythm while removing the old counterparty avatar, full account identity, barcode and complete enumerable order number.
- Waiting-payment and confirmed states keep the fixed black action footer clear of content and Android navigation; all content remains reachable by scrolling.
- A source/implementation side-by-side pixel comparison cannot be produced because the old code has separate commodity and transaction-detail pages rather than this unified consumer detail state.

## Focused comparison evidence

- Fonts and typography: the gold header, 20sp semantic state, 14–15sp product/order names, 11–12sp metadata and 20sp amount hierarchy remain readable without truncation; exact Mini Program font metrics remain unverified.
- Spacing and layout rhythm: `14dp` page margins, `10dp` card gaps, `8dp` radii, compact info rows, separated product rows and fixed `76dp` footer reproduce the source density without clipping.
- Colors and visual tokens: `#C9B69E` source card/gold, `#181205` card text, near-black brown surfaces and semantic gold/green/gray states are retained.
- Image quality and asset fidelity: high-resolution champagne, whisky and fruit assets are sharply cropped at both one- and two-line item layouts; old remote product images were unavailable, so exact subject/crop fidelity is not claimed.
- Copy and content: type, state, store, table, masked order number, products, quantities, authoritative amount breakdown and timeline are complete. The copy explicitly labels Fake authority and never claims actual payment, refund or cancellation success.
- Icons and interaction states: library back, status, help, cloud and confirmation icons share Material optical weight; pay, cancel, admission, refresh, support and reconciliation states are operable with practical tap targets.

## Findings

- [P2] Exact old-runtime visual fidelity remains blocked.
  - Location: complete unified order-detail screen.
  - Evidence: four `1080 × 2400` implementation captures exist, but no same-state old runtime image can be placed beside them; WXML/WXSS provides structure and tokens rather than visual pixels.
  - Impact: layout quality, hierarchy, imagery, scrolling and actions are verified, but subtle rpx-to-dp spacing, font rasterization and original remote-image differences cannot be certified pixel-accurate.
  - Fix: capture an archived old detail state with matching products and status if one becomes available, normalize the app-owned viewport and rerun the comparison.

## Comparison history

- Pass 1: the first Android render exposed a P0 global-theme interaction—`OutlinedButton` inherited an infinite minimum width and broke the footer layout.
- Fix: `_ActionButton` now overrides minimum size and horizontal padding for both outlined and filled variants.
- Pass 2 evidence: all four final Android captures render the footer, content and navigation without overflow, collision or exception. The confirmed Fake state also received a state-consistent masked suffix.
- Source-fidelity remains blocked solely by the missing same-state old runtime visual.

## Implementation checklist

- [x] Old `shoping3` pale brown-gold product and amount hierarchy
- [x] Safe status summary and masked order identity
- [x] Product lines, authoritative amount breakdown and status timeline
- [x] Fake `allowedActions` for payment, cancellation, admission, support and refresh
- [x] Cancel confirmation, conflict and same-request reconciliation
- [x] Offline, unknown, invalid reference and session-invalid states
- [x] Android default, scrolled, confirmed and scenario-selector captures
- [x] `flutter analyze` clean
- [x] Nine dedicated detail tests
- [x] Full Flutter suite: 96 tests passed
- [ ] Same-state old runtime image and normalized side-by-side comparison

## Follow-up Polish

- Replace local Fake catalog imagery only after the production detail projection supplies authoritative image URLs and crop guidance.

final result: blocked
