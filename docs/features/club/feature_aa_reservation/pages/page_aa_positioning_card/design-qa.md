# Design QA — AA 已选座定位凭证 v1

- source visual truth path: 用户于 2026-08-29 当前会话提供的“已选座列表卡”和“POSITIONING CARD”两张旧版截图；稳定源码 `C:\Users\Poplar\Desktop\KingClub-app\pages\Choose\Choose.wxml` / `Choose.wxss` 与 `pages\ticket\ticket.wxml` / `ticket.wxss`
- implementation screenshot paths: `audit/2026-08-29/01-reservation-list-positioning-card.png`; `audit/2026-08-29/02-positioning-card-page.png`
- source pixels: 列表参考约 `631 × 400 px`，完整凭证参考约 `640 × 1365 px`
- implementation pixels: Android emulator `1080 × 2400 px`
- CSS/logical viewport: approximately `411 × 891 dp`; Android density normalization only
- state: `周四 08.27` 已支付已选座；888；十席矩阵第一席为本人；3880 卡座套餐；单人票价 388 元

## Full-view comparison evidence

- 列表态保持旧版日期栏、紫色径向渐变定位卡、左侧 `888 / 日期 / POSITIONING CARD` 与右侧席位、套餐、价格和二维码的双列构图。
- 完整页保持深酒红背景、顶部居中英文标题、紫红渐变主卡、十席矩阵、白底黑色二维码和下方三条入场说明。
- 微信宿主胶囊未复制；Android 系统状态栏与底部手势区属于平台区域，不计入 App 内容偏差。

## Focused region comparison evidence

- Fonts and typography: `888` 使用白色大号衬线字；标题、日期、套餐和说明使用旧版浅粉金层级；文案无缺失或错误换行。
- Spacing and layout rhythm: 主卡、席位矩阵、二维码和票据信息沿一条居中轴排列；列表卡两列比例与旧版一致；返回键已固定在标题栏左侧。
- Colors and visual tokens: 页面使用深酒红径向背景，主卡使用 `#5A1E80 → #AD016A` 径向渐变，未替换成黑金或通用卡片。
- Image quality and asset fidelity: 席位男女图标、`POSITIONING CARD` 字图、列表二维码与二维码中心 King 标识均直接复用稳定版原始 PNG；无代码绘图或占位图。
- Copy and content: `888`、`2026-08-27 20:30-04:00`、`K24500000299`、`3880卡座套餐`、`单人票价：388元` 与三条说明完整保留。

## Comparison history

- Pass 1 P2: 列表定位卡底部出现 2 px 溢出且径向渐变被 `Ink` 表面压暗。
- Fix: 改为直接绘制渐变容器，并压缩价格字号与卡片内部节奏。
- Pass 2 P1: 完整凭证页标题栏宽度按内容收缩，返回箭头压在 `POSITIONING CARD` 标题上。
- Fix: 标题栏强制 `width: double.infinity`，返回箭头固定在左侧 6 dp，标题保持屏幕居中。
- Pass 3 P0: 直接路由进入凭证页时没有上一层路由，纯 `pop()` 返回无响应；首次增加的全局 `canPop: false` 又会阻止左上角主动返回。
- Fix: 根据构建时路由栈分别设置 `PopScope.canPop`；有栈正常 `pop`，无栈时左上角和 Android 系统返回键都 `go('/club/aa')`。
- Post-fix evidence: `01-reservation-list-positioning-card.png` 与 `02-positioning-card-page.png`；无溢出、遮挡或剩余可操作 P0/P1/P2 偏差。

## Verification

- `flutter test test/aa_positioning_card_flow_test.dart test/aa_reservation_flow_test.dart`: 17/17 passed.
- `flutter analyze`: no issues.
- Preview APK built and installed on `emulator-5554`.
- Direct-route device checks: left navigation fallback passed; Android system-back fallback passed; normal pushed-route return passed.

final result: passed
