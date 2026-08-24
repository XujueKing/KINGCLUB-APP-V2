# 会员审核状态页

- Scope ID：`KC-P-009`
- 文档状态：`In Review`
- 所属功能：[会员注册、资料初始化与准入](../../README.md)
- 旧版来源：参数化 `success` + `regist5` 结果
- 路由语义：`MembershipReviewStatusRoute`
- 设计版本：`Onboarding Wireframe v1 / Review`
- 最后更新：2026-08-25

## 用户任务

明确了解会员申请的权威状态、更新时间、需要的下一动作以及能否进入 App。

## 入口、出口与返回

- 入口：pendingReview、changesRequired、rejected 或 suspended；登录/冷启动守卫可 reset 到本页。
- approved：显示明确成功后，用户点击“进入 KingClub” reset App Shell 首页。
- changesRequired：仅打开 snapshot 指定步骤。
- rejected：按 `canResubmit/resubmitAfter` 显示重提或等待；可展示批准客服渠道。
- pending/rejected/suspended 作为安全根，系统返回不能进入 Shell 或旧准入栈。

## 线框

```text
[KingClub]
[状态图标]
会员申请审核中 / 需要补充资料 / 已通过 / 未通过
提交时间 · 最近更新时间
公开、可操作的状态说明

[刷新状态 / 进入 KingClub / 补充资料 / 重新申请]
[联系客服（仅配置可用时）]
[退出登录]
```

## 状态原则

- 不使用 URL 参数拼接标题、成功/失败和目标路由。
- 不显示模型分数、内部规则、审核员身份或风控原文。
- 缓存 pending 可以离线显示并标注“上次更新”；缓存 approved 不能单独授予 Shell 权限。
- 前台刷新、手动刷新或未来 Fake realtime 事件只触发 `getReviewStatus()`，最终状态来自 snapshot。
- 状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)。

## 验收

见 [acceptance.md](acceptance.md)。当前仍不得实现 UI 或接真实审核通知。
