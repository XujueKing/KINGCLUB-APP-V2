# 会员审核状态页

- Scope ID：`KC-P-009`
- 文档状态：`Approved for Development`
- 所属功能：[会员注册、资料初始化与准入](../../README.md)
- 旧版来源：参数化 `success` + `regist5` 结果
- 路由语义：`MembershipReviewStatusRoute`
- 设计版本：`Onboarding Wireframe v1 / Review / Pill Actions`
- 最后更新：2026-08-28

## 用户任务

明确了解会员申请的权威状态、更新时间、需要的下一动作以及能否进入 App。

## 入口、出口与返回

- 入口：pendingReview、changesRequired、rejected 或 suspended；登录/冷启动守卫可 reset 到本页。
- approved：显示明确成功后，只保留“进入 KingClub”一个操作；不显示“刷新状态”或“退出登录”。用户点击后 reset App Shell 首页。
- changesRequired：仅打开 snapshot 指定步骤。
- rejected：按 `canResubmit/resubmitAfter` 显示重提或等待；可展示批准客服渠道。
- pending/rejected/suspended 作为安全根，系统返回不能进入 Shell 或旧准入栈。

## 线框

```text
[状态图标]
会员申请审核中 / 需要补充资料 / 已通过 / 未通过
提交时间 · 最近更新时间
公开、可操作的状态说明

[刷新状态 / 进入 KingClub / 补充资料 / 重新申请]
[联系客服（仅配置可用时）]
[退出登录]

approved 特例：仅显示 `[进入 KingClub]`。
```

## 页面布局

- 本页不显示 Logo、品牌字标或额外顶部装饰。
- 状态图标、标题、说明、更新时间和该状态允许的正式操作构成内容组，在“UI 测试场景”上方的可用空间内水平与垂直居中；approved 内容组只包含“进入 KingClub”按钮。
- “UI 测试场景”保持在页面最下方，不参与正式内容组的居中计算；小屏允许整页滚动，不得遮挡主操作。
- “刷新状态”、进入、补资料和不可重提等审核主操作统一使用完整胶囊圆角；需要刷新的非 pending 状态使用相同 `StadiumBorder` 描边按钮，但 approved 不显示刷新按钮。

## 状态原则

- 不使用 URL 参数拼接标题、成功/失败和目标路由。
- 不显示模型分数、内部规则、审核员身份或风控原文。
- 缓存 pending 可以离线显示并标注“上次更新”；缓存 approved 不能单独授予 Shell 权限。
- 前台刷新、手动刷新或未来 Fake realtime 事件只触发 `getReviewStatus()`，最终状态来自 snapshot。
- “UI 测试场景”只用于本地验收，必须排在正式审核内容之后的页面末尾，不得打断真实审核页的信息和操作层级。
- 状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)。

## 验收

见 [acceptance.md](acceptance.md)。当前只实现本地审核状态切换，不得接真实审核通知。
