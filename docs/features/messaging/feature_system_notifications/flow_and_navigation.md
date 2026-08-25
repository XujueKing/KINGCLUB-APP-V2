# 系统通知流程与导航

```text
ConversationsRoute -> SystemNotificationsRoute
  -> load cached + refresh cursor
  -> tap/expand -> markRead
  -> optional NotificationAction
       -> NavigationCoordinator allowlist
       -> target page re-reads authority
```

- `SystemNotificationsRoute` 建议 `/messages/system`，无外部参数。
- WebSocket `notification.*` 只提示失效；按 eventId 去重后通过 API cursor 补拉。
- `notification.ack` 仅表示接收，`markRead` 才改变阅读状态，两者不得混为一谈。
- “全部已读”携带 readThroughCursor 与幂等键；结果未知查询 unread summary。
- 会话失效清除缓存与动作引用并 reset。
