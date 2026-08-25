# 单聊消息状态机与导航

```text
compose -> queued
  media? -> uploading -> sending
  text   -> sending
sending -> sent -> delivered? -> read?
        -> failed -> retry(same clientMessageId)
sent/delivered/read -> revoked (when server allows)
```

```text
DirectChatRoute(ConversationRef)
  ├─ peer avatar/title -> UserProfileRoute
  ├─ details -> DirectChatDetailsRoute
  ├─ forward -> ContactSelectorRoute(ShareIntentRef)
  └─ media picker -> upload intent -> commit -> send
```

- 历史先展示当前 generation 缓存，再用 beforeCursor 加载权威页；按 messageId/clientMessageId 去重。
- WebSocket 事件携带 eventId/messageId/version，只触发合并或补拉；跨连接顺序以每会话 serverSequence/cursor 为准。
- 打开并实际呈现消息后提交 readThroughMessageId；后台或预加载不发送已读。
- `deleteForMe` 仅对当前用户隐藏；`revoke` 对双方显示撤回占位且受服务端策略控制。
- friendship 变更为 stranger/blocked 时输入区原子关闭，已有发送结果仍按权威状态收口。
