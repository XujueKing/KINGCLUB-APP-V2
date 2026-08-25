# 会话列表数据与 Fake 契约

```text
ConversationSummary
  conversationRef
  peerMemberRef
  displayName
  avatarRef?
  lastMessagePreview
  lastMessageKind
  lastActivityAt
  unreadCount
  isPinned
  isMuted
  isHidden
  relationshipState
  summaryVersion

ConversationListSnapshot
  items[]
  systemUnreadCount
  nextCursor?
  snapshotVersion
```

```text
ConversationRepository
  watchCachedList(generation)
  loadList(query?, cursor?, generation)
  refresh(sinceCursor?, generation)
  setReadState(conversationRef, state, expectedVersion, idempotencyKey)
  hideForMe(conversationRef, expectedVersion, idempotencyKey)
```

- lastMessagePreview 由服务端按消息类型清洗，不把原始媒体 URL/业务 payload 交给列表。
- 未读为非负整数，UI 显示 `99+`；mute 仍累计未读但不用强提醒样式。
- Fake 覆盖排序、搜索、隐藏后新消息恢复、事件重复、离线缓存和会话失效。
