# 会话列表流程与导航

```text
Messages Tab -> ConversationsRoute (/messages)
  ├─ switch Contacts -> ContactsRoute
  ├─ system notifications -> SystemNotificationsRoute
  ├─ direct conversation -> DirectChatRoute(ConversationRef)
  └─ swipe -> markRead/markUnread | hideForMe
```

- `ConversationsRoute` 是 protectedShell/messages 分支根，无 URI 参数或外部打开。
- `ConversationRef` 为进程内不透明引用，带 generation；失效时保留列表并提示刷新。
- WebSocket 事件只标记摘要失效或携带 eventId；Repository 通过增量 API/缓存合并权威版本。
- 打开单聊且首屏权威加载完成后再提交 read cursor，不因预加载或误触直接清零未读。
- 隐藏会话不影响对方、不删除消息；新消息或主动进入后重新显示。
