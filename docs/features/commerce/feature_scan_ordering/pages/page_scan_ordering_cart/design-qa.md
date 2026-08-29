# Design QA — 旧版点单像素复刻 v3

- source visual truth：用户于 2026-08-29 提供的旧版完整点单截图（约 `660 × 1280 px`）及头部、一级分类裁剪图；旧版稳定源码 `pages/shoping/shoping.wxml`、`shoping.wxss`、`app.wxss`
- implementation screenshot：`audit/2026-08-29-legacy-v3/04-catalog-final.png`
- implementation pixels：`1080 × 2400 px`
- viewport：Xiaomi 14 Pro，Android，约 `432 × 960` logical px，density 2.5
- state：KINGBAR 湖南工大店 / 888 / 酒水 / 畅饮套餐 / 轩尼诗 XO 1 件 / 芝华士12年 1 件 / 合计 3710.00
- normalization：按 app-owned 内容宽度等比比较；旧版小程序宿主胶囊、不同平台状态栏和底部系统导航不纳入差异

## Full-view comparison evidence

- 页面恢复旧版黑色连续画布，没有卡片化门店、商品或桌位组件。
- 顶部顺序、左栏/右侧商品双列比例、前三件商品的首屏密度和固定结算栏均与参考图一致。
- 第四件商品继续位于下方滚动区，固定结算栏自然覆盖视窗末端，不影响商品列表滚动。

## Focused region comparison evidence

- Fonts and typography：门店名、地址、一级分类、商品中英文名、规格、价格和结算金额恢复旧版字号层级；`888` 使用 Android serif 回退呈现旧版粗衬线数字轮廓。
- Spacing and layout rhythm：King 标志缩小到 `56 × 36 dp`，一级分类固定 `80dp` 单元和 `36dp` 选中线，左栏宽 `75dp`，商品行高 `176dp`，底栏高 `80dp`。
- Colors and visual tokens：黑底、`#C9B69E` 米金、`#FFB400` 操作黄、低对比地址灰与旧版源码一致。
- Image quality and asset fidelity：直接复用旧版 `logo_2.png`、`HennessyXO.png`、`CHIVAS12.png`、`HennessyVSOP.png`、`vodka.png` 和 `gouwudai.png`，透明瓶图使用 `contain`，无裁切、卡片底或占位图。
- Copy and content：门店名、地址、888、分类、四个商品中英文名、750ML、价格、合计 3710.00 和“去结算”均按参考图恢复。

## Findings

- 无剩余可执行的 P0/P1/P2 差异。
- P3：Android 系统字体的字面栅格与旧版 iOS/微信运行时不可能完全相同，但字号、字重、行高和层级已对齐，不影响本轮验收。

## Comparison history

- v2 P1：门店头部使用圆形 K、V8 验证卡和定位说明，商品使用非旧版素材，整体偏卡片化。
- v3 pass 1：改为原始标志、888、原始透明瓶图、旧版左栏和 3710 结算态；实机截图为 `01-catalog.png`。
- v3 pass 1 P2：King 标志偏大，三个一级分类横向间距与选中线偏宽。
- fix：标志由 `74 × 43 dp` 调整为 `56 × 36 dp`；分类单元由 `104dp` 收至 `80dp`，选中线由 `54dp` 收至 `36dp`。
- v3 pass 2 evidence：`04-catalog-final.png`；头部和一级分类比例已回到参考图，未发现新的 P0/P1/P2。

## Interaction verification

- `03-bag.png`：购物袋展开、数量控件和合计可达。
- `05-confirm-handoff.png`：点击“去结算”进入 KC-P-035，保留 2 件商品和 3710 元商品总价。
- `06-return.png`：系统返回键回到点单页，购物草稿保留。
- 专项组件测试 5/5、全量 Flutter 测试 257/257 通过；`flutter analyze` 无问题。

## v3.1 rework status

- 用户于 2026-08-29 指出 v3 的系统衬线 `888` 并非旧版真实矢量，且商品信息列的字号与纵向节奏偏离原图。
- 已回写 `legacy_pixel_replica_v3.md`，并以 `.F_888` 原始 path 和 `C3V2/C3T2/C3T3` 源码尺寸重新实现、重新实机截图、重新对照。

## v3.1 comparison evidence

- source visual truth：用户于 2026-08-29 本轮提供的 `1080 × 2400` 旧版完整点单截图、`888` 局部图和轩尼诗 XO 商品行局部图；旧版稳定源码 `app.wxss/.F_888`、`pages/shoping/shoping.wxml`、`shoping.wxss`
- implementation screenshot：`audit/2026-08-29-legacy-v3/12-vector-menu-pass1.png`
- implementation pixels：`1080 × 2400 px`
- viewport：Xiaomi 14 Pro，约 `432 × 960` logical px，density 2.5
- state：酒水 / 畅饮套餐 / XO 1 / Chivas 1 / 3710.00；与旧版完整原图同状态
- normalization：源图与实现均为 1080 × 2400；仅忽略时间、信号、系统导航和小程序宿主胶囊差异

### Full-view

- 顶部搜索、King 标志、门店名、地址、三个一级分类、左栏、三件半商品和固定结算栏保持旧版相同信息密度。
- `888` 使用旧版 viewBox `209.72 × 90` 的原始矢量轮廓，并在相同右侧槽位呈现，不再受 Android 字体字形影响。

### Focused regions

- `888` 局部：三个 8 的收腰、上下碗口和字间距来自旧版 path；米金径向渐变来自 `.tablestyle`，不存在文字回退、字距挤压或字体替换。
- XO 商品行局部：商品图槽位按 `190 × 240 rpx` 换算；中文 32 rpx、英文/规格 28 rpx、价格 36 rpx、货币符号/数量 24 rpx；名称组与瓶图顶部对齐，价格和加减按钮与瓶图下部对齐。
- Chivas/VSOP：同一排版模板保持字号、行高和上下节奏一致；英文长名称单行保留，未挤压价格或按钮。

## Required fidelity surfaces

- Fonts and typography：源码 rpx 层级已逐项换算；Android 系统中文字体只保留不可避免的 P3 栅格差异。
- Spacing and layout rhythm：恢复 `C3V2 justify-content: space-between`，不再把商品文字整体垂直居中；价格/数量共用一条基线。
- Colors and tokens：黑底、`#C9B69E`、`#FFB400` 与 `.tablestyle` 径向米金保持源码值。
- Image and vector fidelity：瓶图和 King 标志继续直接复用旧资源；桌号改为旧版真实矢量，不存在代码字形近似。
- Copy and content：门店、地址、桌号、商品中英文、规格、价格、合计和结算文案与参考状态一致。

## v3.1 findings and history

- earlier P1：`888` 使用 Android serif 文本近似，字形不等于旧版矢量。
- earlier P1：商品三行文字整体垂直居中、字号偏小，价格与瓶图下缘的关系错误。
- fix：移植 `.F_888` path 为 `table_888.svg`；商品列改为 138dp 同高 `spaceBetween`，恢复 32/28/36/24 rpx 层级。
- post-fix evidence：`12-vector-menu-pass1.png` 与用户本轮两个局部图；未发现剩余 P0/P1/P2。
- P3：Flutter/Android 与旧版小程序运行时的中文字形抗锯齿略有差异，不影响字号、层级、换行或操作。

## v3.2 rework status

- 用户于 2026-08-29 指出左侧分类文字偏小、旧版固定换行未复现，且门店头部局部尺寸仍与完整原图存在差异。
- 已回写 v3.2 文档冻结规则；在新一轮 1080 × 2400 实机截图完成同状态对照前，本页视觉门禁重新打开。

## v3.2 comparison evidence

- source visual truth：用户本轮提供的旧版完整点单图（图四）、门店头部/一级分类裁剪图（图二）和左栏裁剪图（图三）；旧版 `utils/formatTime.wxs#formatText`、`pages/shoping/shoping.wxss`
- implementation screenshot：`audit/2026-08-29-legacy-v3.2/02-sidebar-header-final.png`
- implementation pixels：`1080 × 2400 px`
- viewport：Xiaomi 14 Pro，约 `432 × 960` logical px，density 2.5
- state：酒水 / 畅饮套餐 / XO 1 / Chivas 1 / 3710.00；与旧版完整原图同状态
- normalization：实现按 1080 × 2400 全屏检查，并以 app-owned 内容宽度与旧版图四等比对照；平台状态栏、系统导航和小程序胶囊不计入差异

### Full-view and focused evidence

- Fonts and typography：左栏普通项使用 15sp、选中项 16sp/500，行高 1.2；`畅饮套餐` 固定 `2 + 2`、`红葡萄酒` 固定 `3 + 3` 换行，不再受 Android 自动换行影响。
- Spacing and layout rhythm：左栏宽 75dp、行项最小高 74dp、横向内边距 4dp；两行文字在选中底色和普通分隔行内均稳定居中。门店头部左边距恢复为 28dp，Logo、标题、888 保持单行且互不挤压。
- Colors and tokens：选中米金、普通灰白、黑底与细分隔线继续使用旧版值；本轮未引入新颜色。
- Image and vector fidelity：King 标志继续复用旧 PNG，`888` 继续使用 `.F_888` 原始矢量；未改动瓶图和购物袋资产。
- Copy and content：分类文案、门店文案、商品文案与旧版一致；换行只改变视觉排版，不改变可访问语义或交互键。

## v3.2 findings and history

- earlier P1：左栏 13/14sp 偏小，4 字和 6 字分类没有执行旧版 `formatText`，导致 `畅饮套餐`、`红葡萄酒` 错误显示为单行。
- earlier P2：门店头部的 Logo、标题与 888 局部比例和左起点仍偏离完整原图。
- fix：显式移植 `formatText` 的 `2 + 2 / 3 + 3` 规则；左栏改为 15/16sp、74dp 行项；头部调整为 28dp 左边距、52 × 34dp Logo、16sp 门店名和 78 × 34dp 的 888 槽位。
- post-fix evidence：`02-sidebar-header-final.png`；未发现新的溢出、裁切、错误换行或 P0/P1/P2 差异。
- P3：Android 中文字体栅格仍与旧版微信运行时略有差异，但字号、字重、行高、换行和区域比例已对齐。

## v3.3 rework status

- 用户本轮指出点击购物袋后的结算前面板没有按旧版图一复刻；当前通用 BottomSheet 不能作为旧版视觉验收结果。
- v3.3 文档已冻结，在新面板实机截图完成前，本页门禁重新打开。

## v3.3 comparison evidence

- source visual truth：用户本轮图一及旧版 `shoping.wxml` 的 `modal-container/modal-content/MM*`、`shoping.wxss`
- implementation screenshot：`audit/2026-08-29-legacy-v3.3/01-bag-pass1.png`
- viewport：Xiaomi 14 Pro，1080 × 2400，约 432 × 960 logical px，density 2.5
- state：两件商品全选、XO 1、Chivas 1、商品总价/合计 3710.00
- normalization：以 app-owned 内容宽度等比对照；状态栏和系统导航差异忽略

### Required fidelity surfaces

- Fonts and typography：全选 16sp/600，商品名 16sp，英文/规格 12sp，价格 16sp，总价 17/18sp；层级与图一一致且没有统一放大。
- Spacing and layout rhythm：470dp 面板从底栏上方升起；54dp 头部、两行各 112dp 黑色商品卡、68dp 浅色总价卡及下方棕金留白复现旧版顺序。
- Colors and tokens：棕金 `#94826C`、黑色商品卡、浅米金总价卡和黄色数量控件均沿用旧版。
- Image and asset fidelity：商品瓶图与购物袋继续使用旧版原始透明 PNG；选中标记与删除使用系统语义图标，未替换业务图像。
- Copy and content：`全选(共2件商品)`、`清空购物袋`、商品三行信息、`商品总价` 和 3710.00 与图一一致。

## v3.3 findings and history

- earlier P1：通用 BottomSheet 缺少旧版全选、商品选择标记、黑色明细卡、浅色总价卡和保留在最底部的点单结算栏。
- fix：将面板改为页面内覆盖层，使底部结算栏保持可见；按旧版 MM6/MM2/modal_1/modal_2 重建布局。
- post-fix evidence：`01-bag-pass1.png`；没有溢出、裁切、错误遮挡或剩余 P0/P1/P2。

final result: passed
