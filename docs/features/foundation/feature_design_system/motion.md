# 动效规范

- 文档状态：`Approved for Development`

## 1. Token

| Token | 时长 | 用途 |
|---|---:|---|
| `motion.instant` | 0ms | 减少动态效果或不应动画的安全状态 |
| `motion.fast` | 120ms | 按压、图标状态 |
| `motion.standard` | 220ms | 普通页面/组件过渡 |
| `motion.emphasized` | 320ms | Sheet、重要状态切换 |

- 默认缓动使用平台自然的 ease-out/ease-in-out；不定义循环呼吸、无限闪烁或大幅弹跳为品牌基础动作。
- loading 动效不得造成频闪；视频自动播放规则由内容页单独评审。

## 2. 原则

- 动效解释层级、来源和结果，不掩盖网络等待。
- 导航动作串行；重复点击不能叠加转场。
- 支付成功、会员审核和扫码结果不能只靠动画传达。
- 系统开启减少动态效果时，位移/缩放转为淡入淡出或 0ms，功能和焦点顺序不变。
- 页面切换必须兼容 Android predictive back 和 iOS 交互返回。
