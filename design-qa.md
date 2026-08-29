# Design QA — Profile Asset Pills Equal Height v9

- source visual truth: 用户当前会话提供的四个资产胶囊局部截图
- implementation screenshot: `docs/features/profile_settings/feature_profile_center/pages/page_my_profile/audit/2026-08-29-equal-pills/01-equal-height-pills.png`
- viewport: Android emulator `1080 × 2400 px`, approximately `432 × 960 dp`
- state: 我的主页 / 四个资产入口同排
- evidence: 余额、金币、钻石和“我的订单”均由固定 `34dp` 高度约束；自动化直接测量四个控件高度全部为 `34.0`，Android 截图显示顶线和底线一致。
- fidelity surfaces: 原有字体、黑金配色、旧版金币/钻石素材与正式文案均保持不变；“我的订单”仅通过香槟金和字重突出。
- findings: no actionable P0/P1/P2 mismatch remains.

final result: passed

---

# Design QA — Onboarding Expanded Preference Catalog v2

- source visual truth: 用户于 2026-08-30 提供的 V2 步骤 3/4 截图用于页面结构与黑金主题；旧版 `C:\Users\Poplar\Desktop\KingClub-app\pages\regist4`、`regist5` 用于目录内容；用户明确要求不复刻旧版固定两列排版
- implementation screenshots: `docs/features/identity/feature_member_onboarding/pages/page_style_music_preferences/audit/2026-08-30-expanded-catalog/01-style-music-top.png`、`03-style-music-selected.png`；`docs/features/identity/feature_member_onboarding/pages/page_drink_event_preferences/audit/2026-08-30-expanded-catalog/01-drink-event-top.png`、`02-drink-event-selected.png`、`03-drink-event-bottom.png`
- viewport: Android emulator `1080 × 2400 px`
- state: 步骤 3/4 默认目录、选中状态与底部操作区域

## Fidelity surfaces

- Fonts and typography: 沿用 V2 已批准中文/英文字阶；所有长标签保持 14dp 正常字号并完整显示。
- Spacing and layout rhythm: 统一高度的内容自适应胶囊以 10dp 横纵间距流式排列；长标签自然占宽，未使用旧版固定两列。
- Colors and visual tokens: 深黑背景、深棕胶囊、金灰描边和香槟金选中态均来自 King 主题，无粉色。
- Image quality and asset fidelity: 本页面没有业务图片资产；偏好胶囊不使用前置图标。
- Copy and content: 旧版 regist4/regist5 的四组 8 项目录全部保留，并分别扩充为 12/11/10/12 项。

## Comparison history

- P1 fixed: V2 原目录仅各 6 项，遗漏旧版多个明确偏好。
- P2 fixed: 已移除偏好胶囊前方的圆形状态位；选择只改变背景、描边和文字颜色，版式更紧凑。
- Post-fix Android 证据显示长标签无截断、选择状态无跳位、主操作与审核说明均可到达。

## Verification

- `flutter analyze`: passed.
- `flutter test test/identity_remaining_flow_test.dart`: 4/4 passed.
- `flutter test test/onboarding_preferences_visual_test.dart`: 2/2 passed.

final result: passed

---

# Design QA — AA 已选座定位凭证 v1

- source visual truth path: 用户于 2026-08-29 当前会话提供的已选座列表卡与完整凭证截图，以及稳定源码 `C:\Users\Poplar\Desktop\KingClub-app\pages\Choose`、`pages\ticket`
- implementation screenshot paths: `docs/features/club/feature_aa_reservation/pages/page_aa_positioning_card/audit/2026-08-29/01-reservation-list-positioning-card.png`; `02-positioning-card-page.png`
- viewport: Android emulator `1080 × 2400 px`, approximately `411 × 891 dp`
- state: 周四 08.27 已支付已选座 / 888 / 3880卡座套餐 / 388元每人
- full-view evidence: 列表紫色定位卡与完整酒红二维码凭证页均按旧版内容顺序、主区域比例和原始素材复刻。
- focused evidence: `888` 衬线字、紫红渐变、2×5 席位矩阵、白底二维码、King 中心图、会员号/套餐/票价与三条说明均已核对。
- comparison history: 修复列表卡 2 px 溢出与渐变压暗；修复完整页标题栏收缩导致返回箭头压住标题；修复直接路由没有上一页时返回无响应，并实机验证左上角、Android 系统返回及正常路由栈返回。最终证据无剩余 P0/P1/P2 差异。
- verification: AA 相关测试 17/17 passed; `flutter analyze` no issues; preview APK installed on `emulator-5554`.

final result: passed

---

# Design QA — Direct Chat WeChat Fluency Pass

- source visual truth: user-provided WeChat-style direct-chat screenshot and the approved legacy chat replication documents
- implementation screenshot: `build/direct-chat-wechat-fluency.png`
- viewport: Android API 37 emulator, `1080 × 2400 px`
- state: chat list → `卡座搭子` → normal direct conversation

## Interaction evidence

- The message list is top-flowing and remains above the composer instead of being squeezed against the bottom edge.
- Input focus and the attachment panel are mutually exclusive; keyboard settling triggers one debounced scroll to the latest message.
- Enter sends, local messages appear immediately, focus is retained after sending, and dragging the list dismisses the keyboard.
- The list uses lazy construction, additional scroll cache and repaint boundaries to reduce avoidable rebuild/jank during normal chat.

## Verification

- Direct-chat widget tests: 5/5 passed.
- Full app smoke tests: 35/35 passed.
- Static analysis: no issues.

final result: passed for UI/Fake fluency; real WebSocket remains gated

---

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

# Design QA — Home Original Banner Replica v7

- source visual truth paths: `assets/legacy/home/legacy_banner_childrens_day.png` (`687 × 415 px`) and `assets/legacy/home/legacy_banner_recruitment.png` (`1375 × 831 px`)
- implementation screenshot paths: `.tmp-home-original-banner-v2.png` and `.tmp-home-original-recruitment-final.png` (`1080 × 2400 px` each)
- combined comparison evidence: `.tmp-home-original-banner-comparison.png` (`1200 × 1500 px`)
- viewport: Android emulator `1080 × 2400 px`, approximately `393 × 873 dp`
- state: children-day and recruitment carousel pages

## Comparison evidence

- Typography and copy: all advertising typography and copy are embedded in the original legacy PNG files, so no Flutter font approximation, wrapping, or letter-spacing drift remains.
- Spacing and layout: the implementation uses the legacy `690:417` canvas ratio and the old `-20rpx` top-offset semantics; the action cards begin immediately below the complete transparent canvas.
- Colors: original pixels and alpha channels are rendered without theme overlays, filters, gradients, or recoloring.
- Image quality: both source assets are displayed with `BoxFit.contain` and high-quality filtering; the complete head/hair and water-droplet silhouettes break above the rectangular background exactly because they are part of the source transparency.
- Content: original `King club` marks, Chinese/English campaign copy, people, and backgrounds are retained as one image per slide.

## Comparison history

- P1 fixed: the former generated split-layer banner changed the subject silhouette, crop, typography, and composition.
- Fix: replaced the generated composition with the exact legacy `ad02.png` and `ad4.png` files and restored the original aspect ratio/top offset.
- Post-fix combined evidence shows no actionable P0/P1/P2 mismatch in either banner state.

## Verification

- `flutter test --update-goldens test/home_legacy_visual_test.dart`: passed.
- `flutter test test/home_legacy_visual_test.dart`: passed.
- `flutter analyze`: no issues.

final result: passed

---

# Design QA — Compact Profile Cover Gallery Picker v8

- source visual truth: 用户于 2026-08-29 对现有黑金编辑主页提出的“按钮更小、可调用相册”修正要求；前一版为 `docs/features/profile_settings/feature_profile_center/pages/page_edit_profile/audit/2026-08-29-black-gold-cover/01-edit-profile.png`
- implementation screenshots: `docs/features/profile_settings/feature_profile_center/pages/page_edit_profile/audit/2026-08-29-gallery-picker/01-compact-cover-button.png`; `02-system-photo-picker.png`; `03-gallery-image-preview.png`; `04-profile-saved-gallery-cover.png`
- viewport: Android device `1080 × 2400 px`; approximately `432 × 960` logical px at density 2.5
- normalization: source and implementation use identical pixel dimensions and device density
- state: 编辑主页、系统相册、相册图片预览、保存后主页

## Full-view and focused comparison evidence

- Typography: “更换封面”降为 12 logical px，未改变其余编辑页字阶。
- Spacing: 胶囊图标、间距和内边距同步缩小；封面、头像、字段列表的既有位置完全保留。
- Colors: App 自有区域继续使用黑、深棕、香槟金和暖白；系统相册保持设备原生主题。
- Image quality: 相册原图在编辑预览和主页使用同一引用与 cover 裁切，无压缩占位图。
- Copy: 正式 UI 只显示“更换封面”和保存提示，没有技术测试文案。

## Findings and comparison history

- Earlier P2 oversized cover control: fixed by reducing icon from 18 to 15, type to 12, and padding from 14×8 to 9×5 logical px.
- Earlier P1 preset-only selection: fixed with the Android system Photo Picker; selection, preview and saved-profile states were captured on-device.
- No actionable P0/P1/P2 issue remains.

final result: passed

---

# Design QA — Profile Edit Black-Gold and Cover v7

- source visual truth: 用户于 2026-08-29 提供的旧粉色编辑弹窗问题截图，以及已批准的 KingClub 黑金“我的”主页
- implementation screenshots: `docs/features/profile_settings/feature_profile_center/pages/page_edit_profile/audit/2026-08-29-black-gold-cover/01-edit-profile.png`; `02-black-gold-dialog.png`; `03-cover-picker.png`; `05-profile-updated-cover.png`
- viewport: connected Android device, `1080 × 2400 px`, approximately `432 × 960` logical px at density 2.5
- state: 编辑主页首屏、昵称编辑、封面选择、保存后主页

## Comparison evidence

- Typography and spacing: 编辑页、弹窗和选择器采用同一黑金字阶与边距，字段值和箭头保持既有对齐规则。
- Colors: 已清除本流程的粉色主题；选中、描边和主操作均使用香槟金。
- Imagery: 封面选择与主页回显使用完全相同的本地资源，裁切稳定且文字叠放不变。
- Copy: “更换封面”与“保存修改”清楚表达本地 Mock 流程，正式界面无测试提示。

## Findings

- 旧粉色弹窗和缺少封面编辑两个 P1 差异均已闭环；无剩余 P0/P1/P2 问题。

final result: passed

---

# Design QA — 首页完整顶部组合吸顶 v7

- source visual truth：用户于 2026-08-29 提供的旧版首页滚动态局部截图（紧凑会员栏、一起玩/组局玩/扫码三联入口及底部阴影）
- implementation screenshots：`docs/features/home/feature_home_hub/pages/page_home/audit/2026-08-29-scroll-header/15-sticky-group-shadow-top.png`、`16-sticky-group-shadow-compact.png`
- viewport：Android 真机 `1080 × 2400 px`；与旧版完整截图同像素尺寸，无密度换算
- state：首页展开态；Banner 滚出后的顶部组合吸顶态

## Full-view comparison evidence

- 展开态顺序保持“会员信息 → Banner → 三联入口 → 两列广告”。
- 滚动态改为“紧凑会员信息 + 三联入口”整体固定，广告从三联入口下方经过，三个入口不会再随 Banner 一起滚走。
- 三联入口底部加入连续黑色柔和阴影，滚动态阴影增强并覆盖广告上沿，形成旧版可见的前后层次。

## Focused region comparison evidence

- Typography：一起玩、组局玩、扫码及英文副标题沿用已验收字号、字重、行高和居中方式。
- Spacing：三张卡保持同高、同顶线、同底线；紧凑会员栏与三联入口之间无异常空档。
- Colors：黑底、米金卡片、深棕文字与黑色阴影均沿用首页旧版色系。
- Image quality：三个入口继续使用旧版背景素材，没有代码绘制或占位替代。
- Copy：`一起玩 / TOGETHER PLAY`、`组局玩 / EXCLUSIVE SEATS`、`SCAN QR` 保持不变。

## Comparison history

- P1 fixed：此前只固定会员栏，三联入口仍会滚走，不符合用户给出的旧版滚动态。
- Fix：把会员栏、Banner 和三联入口合并为一个可折叠头部；仅 Banner 滚出，紧凑会员栏和三联入口共同吸顶，并补充底部阴影。
- Post-fix evidence：`16-sticky-group-shadow-compact.png` 显示三个入口全部固定在紧凑会员栏下方，广告紧接其后且阴影层次可见。

## Findings

- 本轮指定区域无剩余 P0/P1/P2 差异。

final result: passed

---

# Design QA — Home Scroll-Responsive Member Header

- source visual truth: user-provided legacy expanded and compact-scroll screenshots in the current conversation; full-screen source is `1080 × 2400 px`
- implementation screenshots: `docs/features/home/feature_home_hub/pages/page_home/audit/2026-08-29-scroll-header/08-final-top.png` and `docs/features/home/feature_home_hub/pages/page_home/audit/2026-08-29-scroll-header/12-final-compact-matched.png`
- viewport: connected Android device, `1080 × 2400 px`, no density normalization required
- state: expanded home top and compact pinned member header after the hero leaves the viewport
- full-view evidence: the legacy member assets remain visible in both states; the compact header stays pinned while quick actions and the two-column campaign grid continue below it
- focused-region evidence: the compact header preserves the source logo, nickname/level, coin, diamond, and progress hierarchy without replacement assets or copy changes
- typography: existing approved member type scales with the header and remains single-line; no new font or weight drift
- spacing/layout: header height and asset widths interpolate continuously; quick actions are reachable directly below the compact bar; no overflow at the tested viewport
- colors/tokens: black background and champagne-gold member treatment preserved
- image quality: original legacy raster assets remain sharp and correctly proportioned
- copy/content: unchanged
- comparison history: initial P1 was a missing compact state because the member header scrolled away; fixed with a pinned persistent header and sufficient scroll range; post-fix evidence is `12-final-compact-matched.png`
- verification: home widget tests 13/13 passed; static analysis reports no issues

final result: passed

---

# Design QA — Home Header Legacy Logo Scale

- source visual truth: user-provided legacy home screenshot, stable `pages/index/index.wxml` / `index.wxss`, and exact old `images/logo_2.png`
- implementation screenshot: `docs/features/home/feature_home_hub/pages/page_home/home-logo-fixed-2026-08-29.png`
- viewport: connected Android device, `1080 × 2400 px`
- evidence: source and V2 logo SHA-256 match; measured logo is `202 × 107 px`, or `18.70%` of the viewport width, matching the old `140rpx / 750rpx` rule and the original `400 × 213` aspect ratio
- verification: home widget tests 11/11 passed; static analysis reports no issues

final result: passed

---

# Design QA — Home Banner Left-Only Infinite Loop

- source interaction truth: corrected user direction that the home ad must loop only to the left and never page right
- implementation recording: `docs/features/home/feature_home_hub/pages/page_home/home-banner-left-loop-2026-08-29.mp4`
- viewport: connected Android device, `1080 × 2400 px`
- evidence: two automatic cycles use increasing virtual pages (`10000 → 10001 → 10002`) with no visible reset; rightward drag is rejected and leftward drag advances one page
- verification: home widget tests 12/12 passed; static analysis reports no issues

final result: passed

---

# Design QA — VIP / Profile Orders / Payment Notice Corrections

- source visual truth: 用户于 2026-08-29 提供的 VIP 组局、“我的”页与支付页截图
- implementation screenshots: `docs/features/foundation/feature_mock_runtime/audit/2026-08-29-ui-corrections/`
- viewport: connected Android device, `1080 × 2400 px`
- state: VIP 成员区展开；“我的”主页；支付准备态

## Comparison evidence

- VIP：粉色成员面板、席位与按钮全部替换为深黑棕底、香槟金高亮；角色层级与可操作状态仍清楚。
- “我的订单”：使用香槟金实底和深色图文突出，垂直内边距、图标尺寸与同排资产胶囊统一。
- 支付安全提示：盾牌与单行文案共用 `CrossAxisAlignment.center`，真机画面无上浮、下沉或基线错位。

## Findings

- 本轮指定的三处正常 Android 视口问题无剩余 P0/P1/P2 偏差。

final result: passed

---

# Design QA — AA Paid Order Center Continuity v5.2

- source visual truth: approved legacy-derived order-center and AA order-detail contracts
- implementation screenshots: `docs/features/commerce/feature_order_center/pages/page_order_center/audit/2026-08-29-aa-paid-v4/01-all-aa-first.png`, `02-active-aa.png`, `03-aa-detail.png`, `04-back-keeps-active.png`
- viewport: connected Android device, `1080 × 2400 px`, approximately `432 × 960` logical px at density 2.5
- state: all orders, active orders, AA detail and return to active filter

## Evidence

- Typography and spacing preserve the approved dense black-gold order-list hierarchy; the new title, two-line summary, time, state and amount fit without clipping.
- Colors continue the existing champagne, amber amount and mint confirmed-state tokens.
- The approved 3880 package poster is contained cleanly and remains recognizable at list-card size.
- Copy and values remain consistent across list and detail: V5, 08月29日 20:30, 3880卡座套餐 and ¥268.
- Navigation preserves the active filter after returning from the matching order detail.

## Findings

- No actionable P0/P1/P2 mismatch remains in the AA paid-order list/detail continuity.

final result: passed

---

# Design QA — AA Payment to Order Detail v5.1

- source visual truth: the user's legacy black-gold order-detail references supplied on 2026-08-29, plus the approved order-detail contract
- implementation screenshot: `docs/features/club/feature_aa_reservation/qa/2026-08-29/aa-order-detail.png`
- viewport: connected Android device, `1080 × 2400 px`, approximately `432 × 960` logical px at density 2.5
- state: V5 AA reservation, no deductions, server-confirmed payment, paid order detail
- normalization: app-owned content compared at the same portrait viewport; Android system status/navigation chrome excluded from fidelity findings

## Full-view comparison evidence

- The detail preserves the approved black canvas, champagne title/back control, shallow gold information cards, black timeline card and fixed black action footer.
- Information order is stable: confirmed state, order identity, package row, amount summary, progress, then safe actions.
- Physical back returns directly to the V5 positioning-card page; the payment result cannot be submitted again.

## Focused region comparison evidence

- Typography: title, confirmed state, card labels/values, package name and amount use the established order-detail weights without clipping or unintended wrapping.
- Spacing: card insets, row rhythm, image/text separation and fixed footer clearances are consistent; all visible content fits at 1080 × 2400.
- Colors: black, champagne, shallow gold and mint-confirmed tokens remain consistent with the accepted legacy-derived system.
- Image quality: the approved `package_3880_v1.png` asset is used directly with a contained crop; no placeholder or code-drawn replacement appears.
- Copy/content: `KING CLUB AA预订`, `V5 卡座 · 08月29日 20:30`, `3880卡座套餐`, `本人 1 席` and `¥268` remain consistent from quote through payment and detail; no 888-table or scan-order content appears.

## Comparison history

- P1 fixed: payment success previously had no order navigation callback and could not open a real detail state.
- P1 fixed: `order-aa-v5-paid-*` previously fell through to the old V8 scan-order sample.
- P2 fixed: deduction variants could have shown a payment amount different from the detail amount; the opaque quote-version suffix now restores the matching Fake total.
- Post-fix Android evidence shows the dedicated AA detail and a verified return path to the V5 positioning card.

## Findings

- No actionable P0/P1/P2 mismatch remains in the AA payment-to-detail path.

final result: passed

---

# Design QA — AA 详情与确认页黑金主题

- source visual truth path: 用户在 2026-08-29 当前会话提供的原版 `POSITIONING CARD` 黑金截图与粉色确认订单截图
- implementation screenshot paths: `docs/features/club/feature_aa_reservation/qa/2026-08-29/aa-detail-black-gold.png`; `docs/features/club/feature_aa_reservation/qa/2026-08-29/aa-confirm-black-gold.png`
- source pixels: `1080 × 2400`; implementation pixels: `1080 × 2400`
- CSS/logical viewport: Android 约 `432 × 960 dp`，density `2.5`
- normalization: 同尺寸真机截图，忽略系统状态栏与 Android 导航栏差异
- state: A6 微醺畅饮套餐详情；未选择抵扣且未勾选规则的确认订单

## Full-view comparison evidence

- 详情页维持原版黑底径向暗棕光晕、白色大号卡座、米金日期、米金固定报价栏和深棕抢订胶囊。
- 确认页已移除全部粉红、玫红和酒红区域，摘要、抵扣、支付方式与边框改为黑/深棕，标签与可交互强调统一米金。
- 底部实付区域采用米白到米金的轻渐变，金额为深棕，主按钮为深棕胶囊；未勾选规则时保持低对比禁用态。

## Focused region comparison evidence

- 顶部标题、摘要四行、三项抵扣、微信支付、规则行和固定付款栏均在真机完整可见，无粉色残留、遮挡或溢出。
- 套餐详情的卡座编号由沙发图标恢复为原版的大号字母数字组合，并与“卡座”基线对齐。

## Findings

- Earlier P1 fixed: 确认页主体分区和底部付款栏使用粉色/玫红主题，与原版详情黑金体系冲突。
- Earlier P2 fixed: 详情页卡座位置使用沙发图标，未复刻原版大号卡座编号层级。
- Post-fix: 字体层级、间距节奏、黑金色板、现有品牌图片与业务文案均无可执行 P0/P1/P2 问题。
- P3: 当前套餐视觉继续使用仓库内现有 King Club 品牌图，后续拿到原版套餐海报源文件后可再替换，不影响本轮黑金主题验收。

## Implementation Checklist

- [x] 文档先行更新黑金主题约束
- [x] 详情页卡座、状态和底栏改为黑金
- [x] 确认页摘要、抵扣、异常和底栏移除粉色
- [x] Android 1080 × 2400 真机截图核验
- [x] AA 专项测试 15 项通过
- [x] `flutter analyze` 无问题

final result: passed

---

# Design QA — Order Confirmation Alignment v3.1

- source visual truth path: user-provided crops 3–5 in the 2026-08-29 thread, plus `C:\Users\Poplar\Desktop\KingClub-app\pages\shoping2\shoping2.wxml` and `shoping2.wxss`
- implementation screenshot path: `docs/features/commerce/feature_scan_ordering/pages/page_scan_order_confirmation/audit/2026-08-29-legacy-v3.1/01-confirm-alignment.png`
- viewport: Xiaomi 14 Pro, 1080 × 2400 px, approximately 432 × 960 logical px at density 2.5
- state: 888 / two expanded products / 3710 merchandise total / 3680 amount due

## Comparison evidence

- `订单日期`、`桌号`、`报价剩余` 的值均贴同一卡片右内边距，不再因文字宽度停在中部。
- 展开态恢复旧版 `隐藏更多（共2件物品）`，并使用左右贯穿细线、同色中心遮挡、普通小号字和紧凑箭头。
- 折叠态由专项测试确认切换为 `显示更多（共2件物品）`，商品数量与报价保持不变。

## Findings

- 用户指出的两个 P2 对齐问题均已修复；Android 截图未发现新的溢出、遮挡或可操作 P0/P1/P2。
- 专项组件测试 7/7 通过，相关 Dart 静态检查无问题。

final result: passed

---

# Design QA — Legacy Scan Ordering Sidebar/Header v3.2

- source visual truth path: user-provided old full ordering screen and focused header/sidebar crops in the 2026-08-29 thread; `C:\Users\Poplar\Desktop\KingClub-app\utils\formatTime.wxs` and `pages\shoping\shoping.wxss`
- implementation screenshot path: `docs/features/commerce/feature_scan_ordering/pages/page_scan_ordering_cart/audit/2026-08-29-legacy-v3.2/02-sidebar-header-final.png`
- implementation pixels: `1080 × 2400`; Android logical viewport approximately `432 × 960` at density 2.5
- state: 酒水 / 畅饮套餐 / XO 1 / Chivas 1 / 3710.00

## Comparison evidence

- The old `formatText` rule is reproduced explicitly: four-character labels wrap 2 + 2 and six-character labels wrap 3 + 3.
- Sidebar text is restored to the old 26/28rpx hierarchy with 1.2 line height and stable centered rows.
- The store logo, title and original 888 vector are resized/repositioned as a single header row without clipping or competition.
- Product layout, assets, prices, steppers and checkout bar remain unchanged from the preceding approved pass.

## Findings

- Earlier P1 fixed: sidebar labels were undersized and missing deterministic legacy wrapping.
- Earlier P2 fixed: store-header local proportions did not match the full legacy reference.
- No actionable P0/P1/P2 difference remains in the requested regions.

final result: passed

---

# Design QA — Legacy Ordering v3.1 Vector Table Number & Product Rhythm

- source visual truth path: user-provided 2026-08-29 ordering full screenshot plus `888` and Hennessy XO focused crops; `C:\Users\Poplar\Desktop\KingClub-app\app.wxss` and `pages\shoping\shoping.{wxml,wxss}`
- implementation screenshot path: `docs/features/commerce/feature_scan_ordering/pages/page_scan_ordering_cart/audit/2026-08-29-legacy-v3/12-vector-menu-pass1.png`
- source pixels: `1080 × 2400`; implementation pixels: `1080 × 2400`; CSS/logical viewport approximately `432 × 960`, density 2.5
- state: 888 / 酒水 / 畅饮套餐 / XO 1 / Chivas 1 / 3710.00

## Comparison evidence

- Full view: search, venue header, category tabs, left rail, product density and fixed checkout bar retain the old composition.
- Focused `888`: source `.F_888` viewBox/path and `.tablestyle` gold gradient replace the former Android serif approximation.
- Focused product row: 190 × 240 rpx image slot and 32/28/36/24 rpx typography are restored; the title group is top-aligned and price/stepper bottom-aligned through the old `space-between` rhythm.
- Source and implementation were compared at the same 1080 × 2400 viewport and shopping state; platform status/navigation chrome was excluded.

## Findings and history

- Earlier P1 vector fidelity: fixed by using the old source path as `table_888.svg`.
- Earlier P1 typography/rhythm: fixed by restoring source sizing and top/bottom distribution.
- No actionable P0/P1/P2 mismatch remains. Android font rasterization is retained as P3 only.

## Verification

- Dedicated ordering tests: 5/5 passed.
- Static analysis: clean.
- Xiaomi 14 Pro preview build installed and opened at `/commerce/ordering`.

final result: passed

---

# Design QA — Approved Review Enter-only State

- source visual truth: user-provided approved-review screenshot and explicit enter-only instruction on 2026-08-28
- implementation screenshot: `build/review-approved-enter-only.png`
- viewport: Android API 37 emulator, `1080 × 2400 px`

## Comparison evidence

- Approved status keeps the success icon, title, explanatory copy, update time and full-pill `进入 KingClub` action.
- The outlined `刷新状态` action is absent.
- The `退出登录` action is absent.
- The local UI test panel remains collapsed at the bottom and does not interrupt the formal approved-state content.

## Findings

- No actionable P0/P1/P2 mismatch remains for the approved enter-only state.

## Implementation Checklist

- [x] Page documentation updated before UI implementation
- [x] Approved state reduced to one formal action
- [x] Other review states retain their required safety actions
- [x] Android screenshot and accessibility hierarchy verified
- [x] 35 widget flows and static analysis pass

final result: passed

---

# Design QA — Adult Verification Exact Rollback v5

- source visual truth: user-provided Step 1 rollback screenshot on 2026-08-28
- implementation screenshot: `build/adult-exact-rollback.png`
- viewport: Android API 37 emulator, `1080 × 2400 px`

## Comparison evidence

- The legacy prohibition icon and two-line warning remain centered beneath the progress bar.
- Labels are restored exactly to centered `NAME:` and `ID CARD:`.
- Both champagne input capsules retain the source's compact 80%-width proportions.
- The ID visibility icon and the later inline adult-declaration row are absent.
- The face-verification button and city line remain the only elements below the form.

## Findings

- No actionable P0/P1/P2 mismatch remains for the requested rollback state.

## Implementation Checklist

- [x] Page documents updated before rollback implementation
- [x] Later Chinese-label and consent-row revisions removed
- [x] Original centered labels and compact capsules restored
- [x] Android visual capture reviewed
- [x] 35 widget flows and static analysis pass

final result: passed

---

# Design QA — Adult Verification Legacy Structure v4

- source visual truth: user-provided legacy Step 1 screenshot and explicit Chinese-label instruction on 2026-08-28
- implementation screenshot: `build/adult-compact-fields.png`
- viewport: Android API 37 emulator, `1080 × 2400 px`

## Comparison evidence

- The prohibition icon and original two-line warning are restored.
- `NAME:` and `ID CARD:` are replaced by `姓名` and `证件号码`; both labels sit above their fields and align with the fields' left edge.
- Both inputs restore the legacy champagne filled capsule treatment while retaining the approved masked-ID visibility action.
- Both inputs now use the source image's compact proportions: approximately 80% viewport width and 52dp height, instead of the previous near-full-width 68dp treatment.
- The circular declaration control and its complete Chinese declaration copy are unchanged.

## Findings

- No actionable P0/P1/P2 mismatch remains for this requested revision.

## Implementation Checklist

- [x] Page documentation updated before UI implementation
- [x] Legacy warning and filled capsules restored
- [x] Chinese labels aligned to the field left edge
- [x] Adult declaration preserved unchanged
- [x] Android visual capture reviewed
- [x] 35 widget flows and static analysis pass

final result: passed

---

# Design QA — Adult Verification Form v3

- source visual truth: user-provided Step 1 screenshot, two-line warning crop and Chinese floating-label form crop on 2026-08-28
- implementation screenshots: `build/adult-circle-top-final.png`, `build/adult-verification-v3-filled-hidden.png`
- viewport: Android API 37 emulator, `1080 × 2400 px`, approximately `411 × 891` logical px
- states: empty/unaccepted and filled/masked/accepted

## Comparison evidence

- The old two-line `未满18岁未成年人 / 不得饮酒注册会员` copy is replaced by one centered `成年核验` title at a larger bold weight.
- `NAME:` and `ID CARD:` are removed. Both 68dp-high fields use Chinese floating labels (`姓名`, `证件号码`), left-aligned content, dark fill, champagne outline and a 34dp radius for a complete capsule silhouette.
- The identity field masks all 18 characters and provides a right-side visibility action without changing the field layout.
- The inline checkbox copy is exactly `我已阅读并同意：本人已满18周岁，未成年人禁止进入本娱乐场所，遵守店内相关管理规定。` and wraps without clipping.
- The declaration control uses a circular outline, and its visible upper edge is aligned to the first text line's upper edge; the whole row remains tappable.
- The former confirmation dialog is removed; the full pill `人脸核验` action remains disabled until the declaration is checked.

## Findings

- No actionable P0/P1/P2 mismatch remains for the requested Step 1 form revision.

## Implementation Checklist

- [x] Documentation updated before UI implementation
- [x] Adult-verification title hierarchy
- [x] Chinese floating labels and masked identity input
- [x] Visibility toggle and inline adult declaration
- [x] Full pill verification action and consent gate
- [x] Empty and completed Android captures
- [x] 35 widget flows and relevant static analysis pass

final result: passed

---

# Design QA — Onboarding Pill Primary Actions

- source visual truth: user-provided `提交会员申请`、实心 `刷新状态` 和描边 `刷新状态` crops, with explicit instruction that all actions use complete pill corners on 2026-08-28
- implementation screenshots: `build/onboarding-pill-step2.png`, `build/review-pill-final.png`, `build/review-pill-outlined.png`
- viewport: Android API 37 emulator, `1080 × 2400 px`, approximately `411 × 891` logical px
- states: onboarding step 2 with blank image slots; pending review; changes-required review

## Full-view and focused comparison evidence

- The Step 2 `下一步` button keeps its original width, height, champagne fill, dark label, and vertical location.
- Step 1–4 primary actions use a full `StadiumBorder` pill so the four-step registration flow remains consistent.
- Review primary actions use the same complete pill silhouette without changing their fill, label or spacing.
- The outlined `刷新状态` variant uses the same `StadiumBorder`, preserving a continuous capsule border around the black interior.

## Findings

- No actionable P0/P1/P2 mismatch remains for the requested complete-pill standard.

## Implementation Checklist

- [x] Step 1–4 primary actions converted to complete pill shape
- [x] Review pending, approved, rejected and changes-required primary actions synchronized
- [x] Review outlined refresh action synchronized
- [x] Android captures for onboarding, filled review and outlined review states
- [x] 35 widget flows pass
- [x] Relevant static analysis passes

final result: passed

---

# Design QA — Legacy Real-name Step 1 Black-Gold Replica

- source visual truth: user-provided original `regist2` screenshot on 2026-08-28, plus `C:\Users\Poplar\Desktop\KingClub-app\pages\regist2\regist2.wxml` and `regist2.wxss`
- source assets: `C:\Users\Poplar\Desktop\KingClub-app\images\nonine.png`, `camera.png`, and `back.png`
- implementation screenshot: `build/real-name-aligned-up.png`
- source screenshot pixels: approximately `575 × 1212 px`, including iPhone/WeChat chrome
- implementation pixels: `1080 × 2400 px`; Flutter viewport approximately `411 × 891` logical px at Android emulator density
- normalization: compared app-owned content by relative width and vertical order; iPhone frame, WeChat capsule, Android status bar, and Android home indicator were excluded from fidelity findings
- state: onboarding step 1, blank form, before consent confirmation

## Full-view comparison evidence

- The updated order is preserved: prohibition icon, two-line warning, `NAME:`, name field, `ID CARD:`, identity field, face-verification button, and city label.
- The requested V2 `步骤 1/4` title and 25% progress bar remain above the legacy composition.
- Original pink surfaces have been replaced consistently with champagne-gold fields, gold foreground artwork, and a deep-brown button on black.
- No Fake, synthetic-data, or test notice occupies the formal first-screen layout.

## Focused region comparison evidence

- Header: the progress indicator remains visible and reads exactly one of four steps; the legacy back artwork is retained.
- Hero: the original `nonine.png` silhouette remains sharp and proportionally scaled; a gold source-in treatment removes all pink while preserving transparency.
- Form: both pill fields keep the legacy 80% viewport width, centered labels, centered placeholder copy, and matching radii.
- Action: the original camera artwork and `人脸核验` label are centered as one unit inside the deep-brown pill button.

## Required fidelity surfaces

- Fonts and typography: original hierarchy, centered English labels, and two-line Chinese warning are retained with Android-safe Chinese fallbacks; the legal paragraph is intentionally removed.
- Spacing and layout rhythm: the 600/750 control-width ratio is preserved; after removing the paragraph, the hero and form are biased upward to align with the preceding login page's logo position, while most flexible space remains above the bottom action.
- Colors and visual tokens: black canvas, `#C9B69E` champagne gold, gold-brown input fill, and `#24180A` button surface; no pink remains.
- Image quality and asset fidelity: all three legacy raster assets are reused; no icon was redrawn or replaced by a text glyph.
- Copy and content: the legacy warning, labels, button copy, and `SHANGHAI . ZHUZHOU` are retained; the law explanation is removed by explicit user direction.

## Findings

- No actionable P0/P1/P2 mismatch remains for the requested hybrid target.
- The missing WeChat capsule is intentional because this is the Flutter App, not the mini-program host.

## Comparison history

- Pass 1 matched the requested hierarchy and black-gold conversion.
- Pass 2 removed the legal paragraph and redistributed the surrounding flexible space evenly so the hero/form composition no longer leaves an accidental blank region.
- Pass 3 moved the hero/form composition upward to match the preceding login page's top-content rhythm and preserved the bottom action position.

## Implementation Checklist

- [x] Documentation updated before UI code
- [x] Original legacy assets reused
- [x] `步骤 1/4` and progress bar retained
- [x] Pink removed from app-owned content
- [x] Legal paragraph removed and remaining content vertically centered
- [x] Hero/form group aligned upward with the previous page
- [x] Consent moved to the face-verification action without changing the initial layout
- [x] 35 widget flows pass
- [x] Relevant static analysis passes

final result: passed

---

# Design QA — Legacy Welcome and Mobile Login Replica

- source visual truth: user-provided original welcome and login screenshots on 2026-08-28
- source implementation: `C:\Users\Poplar\Desktop\KingClub-app\pages\login` and `C:\Users\Poplar\Desktop\KingClub-app\pages\regist`
- source assets: original `bj.jpg`, `logo_1.png`, `logo_2.png`, and `images/back.png`
- implementation screenshots: `build/legacy-welcome-final.png` and `build/legacy-mobile-login-final.png`
- viewport: Android API 37 emulator, `1080 × 2400 px`, approximately `411 × 891` logical px
- states: welcome consent selected; mobile login idle

## Full-view comparison evidence

- The welcome screen uses the original full-height pink venue photograph and original pink handwritten logo without redrawing either asset.
- Consent, NEXT, business-hours copy and bottom spacing follow the original page hierarchy.
- The login screen restores the original black canvas, gold handwritten logo, champagne labels, pill fields, split verification-code control, bottom NEXT button and city line.
- The Android build intentionally omits the WeChat mini-program capsule; system status and navigation chrome remain platform-owned.

## Comparison history

- Pass 1: login content sat too high, the back control was approximate, and the verification-code split was too even.
- Pass 2: exact legacy back artwork was restored and the form was moved down, but the spacing became too loose.
- Final: top spacing was rebalanced to match the reference, the code control was set to a wider input/narrower action split, and the bottom area was lowered.

## Findings

- No actionable P0/P1/P2 visual mismatch remains for the requested legacy welcome and login replica on the verified Android viewport.
- iOS device-specific safe-area comparison remains a later device acceptance item.

## Implementation Checklist

- [x] Page documentation completed before UI implementation
- [x] Original legacy assets reused
- [x] Main controls and navigation path work with Fake data
- [x] Android screenshots captured and visually reviewed
- [x] 35 widget flows pass
- [x] Relevant static analysis passes

final result: passed

---

# Design QA — Membership Review No-Logo Centered Layout

- source visual truth: the user's final direction to remove all logo treatments and center the formal review content
- implementation screenshot path: `build/membership-review-centered.png`
- viewport: Android API 37 emulator, `1080 × 2400 px`, approximately `411 × 891` logical px
- state: pending membership review, test scenarios collapsed, default text scale

## Full-view comparison evidence

- The black-gold handwritten logo and the earlier generic brand mark are both absent.
- The status icon, title, explanation, update time, primary action and logout action form one centered visual group.
- The local UI test panel remains at the bottom and does not displace the formal content hierarchy.

## Focused region comparison evidence

- Alignment: all formal status copy and actions share the page center line.
- Vertical rhythm: the formal group is centered within the usable region above the test panel.
- Small-screen behavior: the complete layout remains scrollable instead of clipping when available height is reduced.

## Findings

- No actionable P0/P1/P2 issue remains for the requested logo removal and centering.

## Comparison history

- Pass 1 P2: the review page retained a large brand logo above the status content.
- Fix: removed the logo and separated the formal content group from the bottom-only UI test controls.
- Pass 2 evidence: `build/membership-review-centered.png`.

## Implementation Checklist

- [x] Page documentation updated before UI code
- [x] All review-page logo treatments removed
- [x] Formal content centered horizontally and vertically in its available region
- [x] UI test scenarios kept at the bottom
- [x] Android visual capture
- [x] 35-flow widget test and static analysis

## Follow-up Polish

- None for this requested adjustment.

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

---

# Design QA — Login and Onboarding Consent Row Alignment

- source visual truth path: user-provided misalignment crop plus `build/login-consent-aligned.png` (手机号登录页协议勾选行)
- implementation screenshot path: `build/onboarding-realname-aligned.png` (实名与成年核验页告知勾选行)
- viewport: Android API 37 emulator, `1080 × 2400 px`, approximately `411 × 891` logical px at the same device density
- source and implementation density normalization: both screenshots were captured from the same emulator and app build; no scaling or density conversion was required
- state: unchecked, enabled, dark theme, default text scale

## Full-view comparison evidence

- Both screens use the same horizontal page inset and the same compact consent-row hierarchy beneath their primary form controls.
- The onboarding row no longer inherits the enlarged default `CheckboxListTile` typography or minimum tile height.

## Focused region comparison evidence

- Fonts and typography: both consent rows now use Design System `bodySmall`, `13sp`, with the same color and line-height token.
- Spacing and layout rhythm: both rows use a `40 × 40 dp` checkbox hit area, `4dp` checkbox-to-copy spacing and true vertical-center alignment; the former `2dp` top inset was removed.
- Colors and visual tokens: both rows inherit the same theme checkbox border, active color and secondary text color.
- Image quality and asset fidelity: no raster assets are present in this component.
- Copy and content: page-specific wording remains unchanged; only its visual specification is shared.

## Findings

- No actionable P0/P1/P2 mismatch remains in checkbox size, text size or horizontal spacing.

## Comparison history

- Pass 1 P2: 实名认证页使用默认 `CheckboxListTile`，造成约 16sp 文案和偏高的整行布局。
- Fix: replaced it with the same `Row + 40dp Checkbox + 4dp gap + bodySmall` construction used by the 手机号登录页.
- Pass 2 P2: size and typography matched, but top alignment left the visible checkbox below the text center, as shown in the user's crop.
- Fix: both login and onboarding rows now use `CrossAxisAlignment.center`, and the checkbox's extra top inset was removed.
- Pass 3 evidence: `build/login-consent-aligned.png` and `build/onboarding-realname-aligned.png`; the visible checkbox and copy centers now align, while the 40dp hit area and 13sp type remain unchanged.

## Implementation Checklist

- [x] Specification recorded before implementation
- [x] 40 × 40 dp checkbox hit area
- [x] 4 dp control-to-copy gap
- [x] 13sp `bodySmall` copy
- [x] Same checkbox behavior retained
- [x] Android visual comparison
- [x] Widget test and static analysis

## Follow-up Polish

- None for this requested component.

final result: passed

---

# Design QA — Onboarding Test-Aid Placement

- source visual truth path: user-provided `合成数据演示` card crop and request to keep test aids below the production-equivalent UI
- implementation screenshot path: `build/onboarding-real-ui.png`
- viewport: Android API 37 emulator, `1080 × 2400 px`, approximately `411 × 891` logical px
- state: onboarding step 1, unchecked consent, synthetic form values, default text scale

## Full-view comparison evidence

- The production-equivalent sequence is now uninterrupted: title and purpose, name, masked identity number, consent, then primary action.
- The synthetic-data notice begins only after the primary action with a separate 32dp gap, so it no longer changes the form hierarchy.

## Focused region comparison evidence

- Fonts and typography: formal labels and the primary CTA contain no `Fake` wording; the auxiliary card keeps its smaller secondary copy.
- Spacing and layout rhythm: removing the top card brings the form directly below the page introduction; the notice is visually subordinate below the CTA.
- Colors and visual tokens: the core form retains the black/champagne palette; the blue test icon appears only in the auxiliary region.
- Image quality and asset fidelity: no raster assets are involved.
- Copy and content: the CTA now reads `开始核验`; synthetic-data safety copy remains available below the real flow.

## Findings

- No actionable P0/P1/P2 issue remains for the requested ordering.

## Comparison history

- Pass 1 P2: the large synthetic-data card occupied the first content block and pushed the actual form down.
- Fix: moved the card below the CTA, changed the CTA to production-equivalent copy, and applied the same bottom-only rule to step 4 and the review-scenario controls.
- Pass 2 evidence: `build/onboarding-real-ui.png`; the complete core task is visible first and the test aid is clearly secondary.

## Implementation Checklist

- [x] Documentation updated before UI code
- [x] Real-name test card below primary action
- [x] Step-4 Mock notice below both submit actions
- [x] Review test scenarios below formal actions and logout
- [x] Login and SMS test explanations remain after their primary actions
- [x] Android visual capture
- [x] 35-flow widget test and static analysis

## Follow-up Polish

- None for this requested ordering.

final result: passed

---

# Design QA — Membership Review Black-Gold Logo

- source visual truth path: `assets/legacy/home/logo_2.png`, the user-approved black-gold transparent `King club` artwork already used by the login page
- implementation screenshot path: `build/membership-review-black-gold-logo.png`
- viewport: Android API 37 emulator, `1080 × 2400 px`, approximately `411 × 891` logical px
- state: pending membership review, test scenarios collapsed, default text scale

## Full-view comparison evidence

- The obsolete circular `K + KINGCLUB` construction has been removed from the review page.
- The approved handwritten logo is centered above the pending icon and remains visually separate from the status hierarchy.

## Focused region comparison evidence

- Fonts and typography: the brand lettering comes from the supplied raster artwork; it is not recreated with a system font.
- Spacing and layout rhythm: the logo uses the same `190 × 108 dp` box as login and preserves the existing 40dp gap to the status icon.
- Colors and visual tokens: the source champagne/black-gold color is rendered unchanged against the black page.
- Image quality and asset fidelity: the original transparent PNG is shown with `BoxFit.contain`, without crop, stretch, tint, border or synthetic background.
- Copy and content: no additional `KINGCLUB` text remains in the brand region.

## Findings

- No actionable P0/P1/P2 mismatch remains for the requested logo replacement.

## Comparison history

- Pass 1 P2: the review page used the generic code-rendered circle `K + KINGCLUB` mark instead of the supplied venue logo.
- Fix: replaced `KingBrandMark(compact: true)` with the same original asset and dimensions used on mobile login.
- Pass 2 evidence: `build/membership-review-black-gold-logo.png`; the approved source artwork is centered, intact and sharp.

## Implementation Checklist

- [x] Page documentation updated first
- [x] Original user-provided asset reused
- [x] Login-matched 190 × 108 dp sizing
- [x] Generic circle mark removed
- [x] Android visual capture
- [x] 35-flow widget test and static analysis

## Follow-up Polish

- None for this requested logo replacement.

final result: passed

---

# Design QA — Mobile Login Centered Logo

- source visual truth: the user's direction to remove the login heading/caption and center the supplied black-gold logo
- implementation screenshot path: `build/login-centered-logo.png`
- viewport: Android API 37 emulator, `1080 × 2400 px`, approximately `411 × 891` logical px
- state: initial mobile login, UI test explanation collapsed, default text scale

## Full-view comparison evidence

- The `手机号登录` heading and account-creation caption are absent.
- The original handwritten `King club` artwork is centered on the page center line.
- The phone field now follows the logo directly while the consent and Mock behavior remain unchanged.

## Findings

- No actionable P0/P1/P2 issue remains for the requested copy removal and logo alignment.

## Implementation Checklist

- [x] Page documentation updated before UI code
- [x] Heading and caption removed
- [x] Original logo centered without crop or distortion
- [x] Android visual capture
- [x] 35-flow widget test and static analysis

final result: passed

---

# Design QA — Mobile Login Centered Content Group

- source visual truth: the user's direction to center the complete formal login composition
- implementation screenshot path: `build/login-content-centered.png`
- viewport: Android API 37 emulator, `1080 × 2400 px`, approximately `411 × 891` logical px
- state: initial mobile login, UI test explanation collapsed, default text scale

## Full-view comparison evidence

- Logo, mobile field, verification button, consent and account note read as one centered composition.
- The composition is vertically centered within the usable area above the test-only control.
- The `UI 测试说明` control remains at the bottom and does not participate in the formal UI alignment.

## Findings

- No actionable P0/P1/P2 issue remains for the requested whole-content centering.

## Implementation Checklist

- [x] Page documentation updated before UI code
- [x] Formal content grouped and horizontally centered
- [x] Formal content vertically centered in its available region
- [x] Test-only control kept at the bottom
- [x] Small-height layout remains scrollable
- [x] Android visual capture
- [x] 35-flow widget test and static analysis

final result: passed

---

# Design QA — Legacy Scan Ordering Pixel Replica v3

- source visual truth path: user-provided old ordering screenshots in the 2026-08-29 thread, plus `C:\Users\Poplar\Desktop\KingClub-app\pages\shoping\shoping.wxml`, `shoping.wxss` and `app.wxss`
- implementation screenshot path: `docs/features/commerce/feature_scan_ordering/pages/page_scan_ordering_cart/audit/2026-08-29-legacy-v3/04-catalog-final.png`
- source pixels: approximately `660 × 1280`; implementation pixels: `1080 × 2400`; Android logical viewport approximately `432 × 960` at density 2.5
- normalization: app-owned content compared by width; Mini Program host capsule and platform system chrome excluded
- state: 888 / 酒水 / 畅饮套餐 / two selected products / 3710.00

## Comparison evidence

- Original King logo, four transparent bottle images and shopping-bag artwork are reused from the stable old repository.
- Store header, left category rail, borderless product rows, yellow steppers and fixed checkout bar reproduce the reference hierarchy and density.
- First device capture found a P2 oversized logo and over-spread top categories; the final capture follows the corrected `56 × 36dp` logo, `80dp` category units and `36dp` underline.
- Widget interactions for category/search/add/remove/bag/checkout pass 5/5; the full Flutter suite passes 257/257; Android checkout handoff and back return were captured; static analysis is clean.

## Findings

- No actionable P0/P1/P2 mismatch remains in the verified app-owned viewport.
- P3: platform font rasterization differs slightly from the old iOS/WeChat runtime.

final result: passed

---

# Design QA — Legacy Shopping Bag Panel v3.3 + Order Confirmation v3

- source visual truth path: the two old-app screenshots supplied by the user on 2026-08-29, plus `C:\Users\Poplar\Desktop\KingClub-app\pages\shoping` and `pages\shoping2`
- implementation screenshot paths: `docs/features/commerce/feature_scan_ordering/pages/page_scan_ordering_cart/audit/2026-08-29-legacy-v3.3/01-bag-pass1.png`; `docs/features/commerce/feature_scan_ordering/pages/page_scan_order_confirmation/audit/2026-08-29-legacy-v3/01-confirm-pass1.png`; `02-confirm-lower.png`
- viewport: Xiaomi 14 Pro, 1080 × 2400 px, approximately 432 × 960 logical px at density 2.5
- state: two selected products; 3710 merchandise total; safe V2 quote adjustment retained on confirmation

## Comparison evidence

- The missing pre-checkout state now uses the legacy brown sheet, select-all/clear header, black item card, light total card and the original fixed checkout bar.
- The confirmation title is restored to `提交订单`; card width/radius/rhythm, transparent bottle sizing, normal product typography and the fixed amount/button footer follow the old `shoping2` composition.
- The user's requested V2 content is retained in compact legacy-style cards: quote lifetime, discount/due amount, error states and payment-after-order explanation.
- Client-entered coin/balance splitting, direct payment-success claims and real service calls remain excluded by the approved safety gate.

## Findings

- Earlier P1 fixed: the legacy bag-review state was absent.
- Earlier P1 fixed: confirmation typography and value weights were oversized and duplicated amount rows made the product card too tall.
- Post-fix Android evidence shows no clipping, overflow, obscured persistent action, or remaining actionable P0/P1/P2 difference in the requested regions.

final result: passed

---

# Design QA — Legacy AA Package Detail Replica v3

- source visual truth path: the user's second `POSITIONING CARD` reference screenshot supplied on 2026-08-29, `1080 × 2400 px`, plus `C:\Users\Poplar\Desktop\KingClub-app\pages\order\order.wxml` and `order.wxss`
- implementation screenshot path: `docs/features/club/feature_aa_reservation/qa/2026-08-29/aa-detail-legacy-v3.png`
- viewport: connected Android device `1080 × 2400 px`, approximately `432 × 960` logical px at density 2.5
- normalization: source and implementation have the same pixel viewport; Android system chrome was excluded from layout findings
- state: V5 / 2026-08-29 周六 / 3880卡座套餐 / ¥268.00 discounted price

## Full-view comparison evidence

- The title, seat number, date, poster, package copy, age prices, rules and fixed purchase bar follow the same top-to-bottom hierarchy as the reference.
- The complete black-and-gold package poster is rendered at the reference scale instead of the earlier logo-only placeholder.
- The fixed footer keeps `¥268.00`, struck `¥388.00`, the voucher note and the dark capsule `抢订` action visible without obscuring package rules.

## Focused region comparison evidence

- Typography: `POSITIONING CARD` now uses regular weight; V5 remains the dominant display type; package name and suggested price retain the reference emphasis; supporting rows use smaller gray optical weight.
- Spacing: the poster-to-title and copy-row gaps were compressed after the first Android capture so all two-column details and both rule lines remain visible above the footer.
- Colors: the radial black/brown background, champagne-gold labels and cream/gold footer match the old black-gold direction.
- Image quality: the full raster package artwork is used with `BoxFit.contain`; no logo placeholder, CSS drawing or emoji substitutes remain.
- Copy: V5, full date, all six package items, four age prices, matching rule, voucher sentence and both prices match the supplied reference.

## Comparison history

- P1 fixed: the initial implementation used only a King logo in an oversized bordered panel; replaced with the complete package poster.
- P2 fixed: package items wrapped and pushed the age/rule content below the persistent footer; compact two-column cells and vertical rhythm now keep the complete content visible.
- Post-fix evidence: `aa-detail-legacy-v3.png` shows no clipping, overflow, hidden persistent action or remaining actionable P0/P1/P2 mismatch.

## Findings

- No actionable P0/P1/P2 issue remains in the requested package-detail state.
- P3: Android system-font rasterization is slightly different from the original Mini Program runtime.

final result: passed

---

# Design QA — AA Confirmation Terms Row Alignment v4

- source visual truth path: the user's cropped rules-consent reference supplied on 2026-08-29
- implementation screenshot paths: `docs/features/club/feature_aa_reservation/qa/2026-08-29/aa-confirm-terms-aligned.png`; `aa-confirm-terms-sheet-aligned.png`
- viewport: connected Android device, `1080 × 2400 px`, approximately `432 × 960` logical px at density 2.5
- normalization: source focused region and implementation focused region compared at the same dark confirmation state; app-owned content only
- state: quote ready, rules unchecked; rules sheet opened in the interaction capture

## Full-view comparison evidence

- The consent group stays centered below the payment row and above quote-expiry information without changing the surrounding confirmation layout.
- Opening `查看` still presents the complete four-item reservation-rules sheet.

## Focused region comparison evidence

- Typography: consent copy and `查看` use the same 12dp optical size and a shared vertical center.
- Spacing: the former `Expanded` spacer was removed; checkbox, consent copy and `查看` now form one compact `mainAxisSize.min` group with 7dp and 5dp controlled gaps.
- Colors: existing black, muted-gold and champagne text tokens are unchanged.
- Image quality: no raster imagery appears in this focused control.
- Copy: the consent sentence and `查看` label are unchanged.

## Comparison history

- P2 fixed: `Expanded` pushed `查看` to the far edge, leaving an obvious empty interval after the rules copy.
- P2 fixed: top padding aligned the copy independently from the checkbox and action; all three now share `CrossAxisAlignment.center`.
- Post-fix Android evidence shows one aligned, uninterrupted consent group and a working rules sheet.

## Findings

- No actionable P0/P1/P2 mismatch remains in the requested consent row.

final result: passed

---

# Design QA — AA Confirmation Checkbox Column Alignment v4.1

- source visual truth path: the user's confirmation screenshot and focused consent-row crop supplied on 2026-08-29
- implementation screenshot path: `docs/features/club/feature_aa_reservation/qa/2026-08-29/aa-confirm-checkbox-column.png`
- viewport: connected Android device, `1080 × 2400 px`, approximately `432 × 960` logical px at density 2.5
- normalization: same confirmation state and device viewport; system chrome excluded
- state: quote ready, all deduction options and rules unchecked

## Full-view comparison evidence

- The rules checkbox now shares the same left column as the coupon, coin and balance checkboxes.
- The rules copy and `查看` remain a compact uninterrupted group without the former expanding blank interval.

## Focused region comparison evidence

- Typography: consent copy and `查看` retain a shared 12dp size and centered baseline.
- Spacing: the consent row now uses the same 18dp horizontal inset and default checkbox geometry as `_DeductionRow`.
- Colors: the original muted-gold checkbox border and text palette remain unchanged.
- Image quality: no image assets appear in this focused control.
- Copy: consent and action labels remain unchanged.

## Comparison history

- P2 fixed: the v4 centered content group moved the rules checkbox inward relative to the three deduction checkboxes.
- Fix: removed the centered `FittedBox`, restored the same 18dp left inset/default checkbox geometry, and retained a controlled 5dp text-to-action gap.
- Post-fix evidence shows all four checkbox outlines on one vertical axis with no overflow or text wrapping.

## Findings

- No actionable P0/P1/P2 mismatch remains in the requested checkbox alignment.

final result: passed

---

# Design QA — AA Confirmation to Payment Handoff v5

- source visual truth path: approved payment UI in `docs/features/commerce/feature_payment/pages/page_payment_result/README.md` and the accepted AA confirmation flow
- implementation screenshot paths: `docs/features/club/feature_aa_reservation/qa/2026-08-29/aa-payment-ready.png`; `aa-payment-success.png`
- viewport: connected Android device, `1080 × 2400 px`, approximately `432 × 960` logical px at density 2.5
- state: V5 AA order, ¥268.00 ready state and server-confirmed success state

## Full-view comparison evidence

- AA confirmation now replaces into the existing black-gold payment page rather than stopping at a transient submission dialog.
- Ready and success states keep the approved payment hierarchy, fixed action placement and server-confirmation wording.

## Focused region comparison evidence

- Typography: AA title, V5/package subtitle and ¥268.00 use the existing payment-page hierarchy without wrapping or clipping.
- Spacing: summary, authority amount, payment method, notice and footer retain the accepted vertical rhythm.
- Colors: no new color tokens were introduced; the black, champagne and cream payment system is preserved.
- Image quality: the existing WeChat payment asset and legacy success visual remain unchanged.
- Copy: order source and amount now correctly read `KING CLUB AA预订`, `V5卡座 · 3880卡座套餐`, and `¥268.00`.

## Findings

- No actionable P0/P1/P2 issue remains in the AA payment ready/success handoff.

final result: passed

---

# Design QA — Order Detail Matches Confirmation Typography v6

- source visual truth: 用户于 2026-08-29 提供的订单详情与提交订单截图，以及已验收 `01-confirm-alignment.png`
- implementation screenshot: `docs/features/commerce/feature_order_center/pages/page_order_detail/audit/2026-08-29-layout-v6/01-paid-scan-order.png`
- viewport: connected Android device, `1080 × 2400 px`
- state: 已支付扫码订单，888号桌，两件酒品

## Comparison evidence

- Typography: 顶栏、信息行、商品名、英文规格、容量、单价、数量、小计和金额层级均采用提交订单的同组参数。
- Spacing: 卡片水平内边距、商品行垂直间距、图片到文字间距和金额行节奏与已验收提交订单一致。
- Imagery: 轩尼诗 XO 与芝华士12年继续使用同一原始商品素材，并统一为 44×70 contain 展示。
- Content: 已支付、888号桌、订单编号、两件商品和 `3710 / -30 / 3680` 均保持不变。

## Findings

- 本轮指定的字体与排版差异无剩余 P0/P1/P2 问题。

final result: passed
