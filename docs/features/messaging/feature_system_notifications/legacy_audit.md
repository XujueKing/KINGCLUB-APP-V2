# 系统通知旧版审计

- 文档状态：`Approved for Development`

| 旧实现 | 风险 | V2 取舍 |
|---|---|---|
| `S231202504270688` | JSON 字符串 + type code + 自由 content 数组 | 受控 NotificationSummary/Detail |
| 金额/金币卡片 | 通知视觉可能被误认为账本 | 明示摘要，目标页权威复核 |
| `moreDetail` 空实现 | 卡片没有稳定动作契约 | NotificationAction allowlist |
| 页码 concat | 重复、乱序和已读未定义 | cursor + notificationVersion |
| 系统消息伪会话 | 和聊天未读混淆 | 固定独立入口与 unreadCount |
