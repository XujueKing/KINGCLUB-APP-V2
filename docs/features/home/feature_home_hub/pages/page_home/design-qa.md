# Legacy Home Replica v1 视觉 QA

- 日期：2026-08-28
- 当前结果：`blocked`（功能性 UI Mock 已验收；严格像素并排对比待补）
- 参考：用户提供的旧版微信小程序首页截图
- 实现基线：`test/goldens/home_legacy_393x852.png`
- Android 实现截图：`qa/android_home_1080x2400.png`

## 已通过的检查

- App 内未绘制手机外框、系统状态栏内容或微信右上角胶囊。
- 顶部恢复旧版 Logo、认证、等级、金币、钻石和经验条。
- 首屏顺序恢复为 Banner、三联入口、两列运营海报。
- 底栏恢复旧版悬浮胶囊以及首页、消息、内容爱心、储物柜、我的五个位置。
- 中央白底粉色爱心为内容 Tab，不再映射安全扫码。
- 393×852 Golden 无布局溢出；Flutter analyze 和 Widget 测试通过。
- Android 37 语义树确认全部首屏元素与五个 Tab 已渲染并具备点击区域。
- Android 37 模拟器冷重启后已成功捕获完整设备实现截图，页面不再黑屏。
- 2026-08-28 新增设备默认态、运营详情和滚动区截图，见 [ui-audit.md](ui-audit.md)。
- HOME-M01～M14、360～430dp、200% 文字和减少动画均已自动化覆盖。
- 三联入口字体、比例、旧 PNG、按压态和 3/6/9 秒连续流光已完成独立复核，结果见 [components/component_quick_actions/design-qa.md](components/component_quick_actions/design-qa.md)。

## 黑屏排查记录

- 症状：Android 状态栏可见，Flutter 页面像素层全黑，但语义树与点击区域完整存在。
- 排除：Flutter analyze、Widget/Golden 测试、图片资源加载和页面语义均正常；移除底栏模糊后热重启仍黑。
- 处理：冷重启 Android 模拟器并重新运行应用后，Flutter Surface 恢复正常合成。
- 稳定性调整：底栏实时 `BackdropFilter` 已改成视觉接近的深棕实底和阴影，降低模拟器图形后端压力。

## 当前阻断

- 原参考截图未作为当前审计的本地源文件保留，无法按同视口生成参考图 + 实现图的组合对比证据。

## 下一次 QA

1. 若需严格 1:1 像素验收，将原参考图保存到本页 `qa/reference/` 下。
2. 用同视口并排对比后，修正可见差异并重新捕获。
3. 像素对比通过后把本文件最终状态改为 `passed`。

当前 `blocked` 只阻止严格像素验收和项目级 `UI Flow Approved`，不撤销已完成的 `UI Mock Implemented`；真实接口仍不得接入。

---

# Design QA — 首页顶部旧版 Logo 比例修正

- 日期：2026-08-29
- source visual truth：用户提供的旧版首页截图、稳定基线 `pages/index/index.wxml` / `index.wxss`，以及原始 `images/logo_2.png`
- implementation screenshot：[home-logo-fixed-2026-08-29.png](home-logo-fixed-2026-08-29.png)
- viewport：Android 真机 `1080 × 2400 px`
- state：首页默认 Fake 场景

## 对照证据

- 素材一致：V2 `assets/legacy/home/logo_2.png` 与旧版 `images/logo_2.png` 的 SHA-256 完全一致；保留香槟金手写 `King club`，无重新绘制、染色或裁切。
- 比例一致：旧版 CSS 为 `140rpx` / `750rpx`；真机 Logo bounds 为 `202 × 107 px`，占 `1080px` 页面宽约 `18.70%`，并保持原图 `400×213` 比例。
- 排版一致：Logo、昵称/性别/等级、金币/钻石和经验条统一使用同一屏宽换算，不再把 `rpx` 直接当作 Flutter `dp`。
- 范围受控：Banner 内装饰 Logo、登录页及会员准入页未修改。

## 验证

- `test/home_flow_test.dart`：11/11 passed。
- `flutter analyze`：0 issue。
- Android 真机：Logo bounds `[42,193][244,300]`，无遮挡、拉伸或溢出。

final result: passed for the focused home-header logo correction; the older full-page strict pixel gate remains separately blocked pending a locally retained original full screenshot

---

# Design QA — 顶部 Banner 单向左循环

- 日期：2026-08-29
- source interaction truth：用户纠正为“只向左翻、循环，不要向右翻”
- implementation recording：[home-banner-left-loop-2026-08-29.mp4](home-banner-left-loop-2026-08-29.mp4)
- viewport：Android 真机 `1080 × 2400 px`

## 交互证据

- 自动轮播使用连续虚拟页序列 `10000 → 10001 → 10002…`，每次都向同一左侧方向推进，不再在第二张结束后反向动画回第一张。
- 页面内容按虚拟页奇偶映射为两张广告，循环过程中不执行可见跳页。
- 手势仅接受向左拖动；向右拖动保持当前广告不变。
- 减少动态效果开启时仍停止自动播放。
- 真机录屏覆盖两个连续自动切换周期，页面布局、指示点和下方内容无抖动或重排。

## 验证

- `test/home_flow_test.dart`：12/12 passed，包含连续两次同向轮播、拒绝向右手势及允许向左手势。
- `flutter analyze`：0 issue。

final result: passed

---

# Design QA — 首页顶部 Banner 旧版原图一比一复刻 v4

- 日期：2026-08-29
- source visual truth：`assets/legacy/home/legacy_banner_childrens_day.png`（旧版 `ad4.png`，`687 × 415 px`）与 `assets/legacy/home/legacy_banner_recruitment.png`（旧版 `ad02.png`，`1375 × 831 px`）
- implementation screenshots：项目根目录 `.tmp-home-original-banner-v2.png`、`.tmp-home-original-recruitment-final.png`
- combined comparison：项目根目录 `.tmp-home-original-banner-comparison.png`
- viewport：Android 模拟器 `1080 × 2400 px`；Flutter 逻辑视口约 `393 × 873 dp`
- normalization：两张原图均按旧版 `690:417` 画布比例、`BoxFit.contain` 和相同首页内容宽度显示；未进行裁切、重绘或图层拆分
- state：首页儿童节 Banner 与招聘 Banner 两个轮播状态

## 全图与局部对照

- 图片：人物、发丝/水珠越框透明区域、背景、旧版 `King club` 标识和广告文案均来自同一张旧版 PNG，像素内容没有被 Flutter 重新生成。
- 布局：Banner 画布恢复旧版 `690:417` 比例，并按旧版 `margin-top:-20rpx` 语义上移；透明画布允许人物头顶和水珠自然高于矩形背景。
- 字体与文案：广告内全部字体、字重、换行、倾斜和文案由原图保留，不再使用 Flutter 文本近似。
- 色彩：原图色彩和透明通道直接呈现，没有粉色/黑金主题覆色、渐变或代码滤镜。
- 下游节奏：三联入口紧接 Banner 下方，未覆盖透明越框部分；轮播仍只向左循环。

## 比较历史

- P1（v3）：将人物、背景和文案拆成生成图层，人物轮廓、裁切、字体和整体比例均与旧版存在明显差异。
- 修复：废弃生成式组合，直接接入旧版缓存中的完整 `ad02.png`、`ad4.png`，恢复 `690:417` 画布和旧版负顶距。
- 复验：`.tmp-home-original-banner-comparison.png` 同屏展示原始 PNG 与模拟器实装；人物、Logo、文字、背景和透明越框轮廓一致，未发现可执行的 P0/P1/P2 差异。

## 验证

- `flutter test --update-goldens test/home_legacy_visual_test.dart`：passed。
- `flutter test test/home_legacy_visual_test.dart`：passed。
- `flutter analyze`：0 issue。
- `test/home_flow_test.dart`：13/13 passed（本轮实现后已通过）。

final result: passed

---

# Design QA — Banner 人物越框效果 v3（已由 v4 原图方案取代）

- 日期：2026-08-29
- source visual truth：用户在当前会话提供的旧版招聘 Banner 与儿童节 Banner 截图
- implementation screenshots：项目根目录 `.tmp-home-final-proof-a.png`、`.tmp-home-final-proof-b.png`
- viewport：Android 模拟器 `1080 × 2400 px`
- state：首页音乐 Banner 与招聘 Banner 两个轮播状态

> 本节仅保留历史比较记录。v3 的生成式分层实现已废弃，当前有效验收结论以“首页顶部 Banner 旧版原图一比一复刻 v4”为准。

## 对照结果

- Banner 背景继续按原版圆角框裁切。
- 人物前景改为独立透明图层，头顶、头发和外扩轮廓不再被圆角框上边缘截断。
- 人物越框只发生在 Banner 自身预留区域内，没有覆盖会员信息栏或三联入口。
- 两张 Banner 共用同一轮播控制与向左循环逻辑，前景和背景同步移动。

## 验证

- `test/home_flow_test.dart`：13/13 passed。
- `flutter analyze`：0 issue。
- Android 预览已重新构建、安装并完成两个轮播状态截图核对。

final result: passed

---

# Design QA — 完整顶部组合吸顶修正

- source visual truth：用户于 2026-08-29 提供的旧版首页滚动态局部截图
- implementation screenshots：`audit/2026-08-29-scroll-header/15-sticky-group-shadow-top.png`、`audit/2026-08-29-scroll-header/16-sticky-group-shadow-compact.png`
- viewport：Android 真机 `1080 × 2400 px`
- state：展开态与 Banner 滚出后的组合吸顶态

## 对照结果

- 会员栏压缩后继续吸顶；一起玩、组局玩、扫码三张卡同时固定在会员栏下方。
- Banner 单独滚出，运营广告从吸顶组合下方滚动，不再把三联入口带走。
- 三卡同高同基线，底部增加柔和黑色投影；字体、配色、素材和文案均保持旧版基线。

## 比较历史

- P1：旧实现只保证会员栏吸顶，三联入口没有固定。
- 修复：重构为完整可折叠顶部组合，并加入随压缩进度增强的底部阴影。
- 复验：`16-sticky-group-shadow-compact.png` 中三联入口完整固定且广告位于其后，无溢出、跳动或遮挡。

## 验证

- `test/home_flow_test.dart`：13/13 passed。
- `flutter analyze`：0 issue。

final result: passed

---

# Design QA — 首页滚动紧凑会员栏

- 日期：2026-08-29
- source visual truth：用户在当前会话提供的旧版首页展开态与滚动紧凑态截图；完整参考为 `1080 × 2400 px`，紧凑区域另有局部裁切参考
- implementation screenshots：`audit/2026-08-29-scroll-header/08-final-top.png`、`audit/2026-08-29-scroll-header/12-final-compact-matched.png`
- viewport：Android 真机 `1080 × 2400 px`，与完整旧版参考一致，无额外密度缩放
- state：首页顶部展开态；顶部 Banner 滚出后的紧凑吸顶态

## 对照证据

- 布局：展开态保持原会员区；滚动后会员区缩小并固定在状态栏下，三联入口与两列运营广告继续从其下方滚动，未再完全消失。
- 字体：昵称、等级与资产数字沿用已验收的首页字体、字重和单行截断规则；缩放过程中比例同步收紧。
- 色彩：紧凑栏保持纯黑底与香槟金信息色，没有新增粉色或其他主题漂移。
- 图片：继续使用旧版 `logo_2.png`、性别、金币与钻石资产，没有用代码图形替代。
- 文案：会员信息、三联入口和广告文案均未改写。
- 交互：上滑连续压缩并吸顶，继续上滑可让 Banner 完全滚出；回顶恢复完整尺寸；首页重新选择仍回顶。

## 比较历史

- 初次核查 P1：会员头部作为普通列表项完全滚出，旧版紧凑态缺失。
- 修复：改为固定的两态会员头部，并补足页面尾部滚动空间，使旧版“紧凑栏 + 三联入口 + 广告流”状态可达。
- 复验：`12-final-compact-matched.png` 中紧凑会员信息持续可见，三联入口完整出现在其下方，无遮挡、溢出或突然跳变。

## 验证

- `test/home_flow_test.dart`：13/13 passed，覆盖压缩、吸顶、Logo 同步缩小和回顶恢复。
- `flutter analyze`：0 issue。
- focused region：紧凑会员栏是本次唯一新增视觉区域，已用完整真机截图中的顶部区域核对，无需额外局部实现截图。

final result: passed
