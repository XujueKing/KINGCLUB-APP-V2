# Design System v1 Token 基线

- 文档状态：`In Review`
- 原则：页面只使用语义 Token；下列色值是 V1 评审基线，不是允许现在编码的常量。

## 1. 颜色

| Token | 建议值 | 用途 |
|---|---|---|
| `color.background.canvas` | `#080706` | App 主背景 |
| `color.background.surface` | `#141210` | 卡片、列表与导航栏 |
| `color.background.elevated` | `#1E1A16` | 弹窗、Sheet、浮层 |
| `color.brand.primary` | `#C9B69E` | 选中态、重点描边、品牌信息 |
| `color.brand.strong` | `#E2C8A6` | 高强调文字/图标 |
| `color.onBrand` | `#15110D` | 金色实心按钮上的内容 |
| `color.text.primary` | `#F7F3EE` | 正文和标题 |
| `color.text.secondary` | `#B9B1A8` | 次要说明 |
| `color.text.disabled` | `#7C756E` | 禁用内容；不得用于关键正文 |
| `color.border.default` | `#3A332C` | 分隔和输入描边 |
| `color.status.success` | `#55C98A` | 成功 |
| `color.status.warning` | `#F2B84B` | 警告/待处理 |
| `color.status.danger` | `#FF646A` | 错误/破坏性动作 |
| `color.status.info` | `#78AFFF` | 信息提示 |
| `color.scrim` | `#000000B8` | 模态遮罩 |

- 任意文字/背景组合必须在组件验收中测量对比度；普通文字至少 4.5:1，大号文字和关键图形至少 3:1。
- 状态不能只靠颜色表达，必须同时提供图标、文字或形状变化。
- 透明度不能用来绕过对比度要求；禁用控件仍需可辨识。

V1 提案的关键静态组合已计算：主文字/Canvas `18.22:1`、次文字/Canvas `9.51:1`、品牌金/Canvas `10.23:1`、onBrand/品牌金 `9.54:1`、危险色/Canvas `6.98:1`。实际组件仍须按最终背景、透明度和状态重新验收。

## 2. 排版

使用平台系统字体栈，字重优先 400/500/600/700。

| Token | 字号/行高 | 用途 |
|---|---|---|
| `type.display` | 32/40, 700 | 极少量品牌大标题 |
| `type.titleLarge` | 24/32, 700 | 页面主标题 |
| `type.titleMedium` | 20/28, 600 | 区块标题 |
| `type.titleSmall` | 17/24, 600 | 卡片/导航标题 |
| `type.bodyLarge` | 17/26, 400 | 重点正文 |
| `type.body` | 15/24, 400 | 默认正文 |
| `type.bodySmall` | 13/20, 400 | 辅助信息 |
| `type.label` | 14/20, 600 | 按钮与标签 |
| `type.caption` | 12/18, 500 | 时间、徽标辅助；非关键长文 |

- 金额、验证码和倒计时允许使用等宽数字特性，但不引入独立字体文件。
- 文案不得依赖固定行数遮盖；关键操作和金额不能截断。

## 3. 间距、尺寸与圆角

- 间距基准：`4, 8, 12, 16, 20, 24, 32, 40, 48` logical px。
- 页面水平边距：窄屏 16；宽手机 20；内容最大宽度规则见响应式文档。
- 最小触控区域：48×48；主要按钮可视高度 52，普通输入高度不低于 52。
- 圆角：small 8、medium 12、large 16、sheet 24、pill 999。
- 描边：默认 1；焦点高亮 2；不要用极细低对比分隔线承载结构。

## 4. 阴影与层级

深色主题优先使用表面色差和描边区分层级，阴影只用于浮层：

| 层级 | 用途 |
|---|---|
| 0 | Canvas |
| 1 | 卡片/列表 |
| 2 | 底部导航、粘性栏 |
| 3 | Menu/Tooltip |
| 4 | Dialog/Bottom Sheet |

页面不得任意提高 z-index；全屏相机、系统权限和支付 SDK 由各自页面/平台契约管理。
