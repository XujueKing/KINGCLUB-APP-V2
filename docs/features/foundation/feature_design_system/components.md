# 基础组件与状态矩阵

- 文档状态：`Approved for Development`

## 1. V1 基础组件

| 组件 | 必须状态 |
|---|---|
| Primary/Secondary/Text/Destructive Button | idle、pressed、focused、disabled、loading |
| Text Field / OTP Field | empty、focused、filled、error、disabled、readOnly |
| App Bar | default、scrolled、transparent-on-media |
| Primary Navigation | unselected、selected、badge、disabled-by-transition |
| Card / List Tile | idle、pressed、selected、disabled |
| Segmented Control / Tabs | selected、unselected、overflow-safe |
| Dialog / Bottom Sheet | open、actionLoading、dismissBlocked、error |
| Snackbar / Banner | info、success、warning、error、offline |
| Avatar / Media Thumbnail | loading、loaded、placeholder、failed、restricted |
| Badge / Chip | default、selected、status、count、99+ |
| Progress | determinate、indeterminate、skeleton |
| Empty/Error/Permission State | title、说明、主动作、可选次动作 |
| Pull to Refresh / Pagination Footer | idle、refreshing、loadingMore、end、retry |

## 2. 通用反馈规则

- 页面首次加载使用页面级骨架或局部进度，不用无限全屏 Spinner 遮盖已有内容。
- 空态解释“为什么为空”和可执行下一步；不把接口错误伪装成空态。
- 错误组件使用稳定用户文案，requestId 仅在明确的诊断复制动作中提供，默认不展开技术细节。
- Toast/Snackbar 不用于必须由用户确认的风险、支付结果或会话失效。
- 破坏性操作必须使用明确动词和二次确认；取消按钮保持可发现。
- loading 按钮保持原宽度并阻止重复提交，结果未知时不得显示成功。

## 3. 组件边界

- 基础组件只表达视觉与通用交互，不访问 Repository、Router、SecureStore 或平台 SDK。
- 业务卡片（订单卡、会话气泡、储物柜格子等）属于各自 feature，不提升为全局组件。
- 两个页面长得相似不等于业务语义相同；抽象必须有三个真实消费者或明确平台级语义。

## 4. 图标与品牌资产

- 功能图标使用一致的线宽、24px 基准和 filled selected 变体。
- 全 App 顶部返回控件使用 48×48px 点击区域，可见箭头高度统一为 22px，并与标题文字在同一标题栏内垂直居中。
- 窄高比的旧版 `back.png` 必须按 22px 高度等比缩放，不得只设宽度导致高度放大，也不得强行拉伸为正方形。
- 自定义标题栏不得通过单独的 `top` 偏移对齐返回键；返回键、标题和右侧动作必须共用同一垂直中线。
- 不用 Emoji 作为正式功能图标。
- 旧 PNG 资产先登记尺寸、透明边界和授权；优先取得 SVG/高清源文件后再进入 UI。
- Logo 不拉伸、不加未经批准的阴影/渐变，深色背景保留安全留白。
