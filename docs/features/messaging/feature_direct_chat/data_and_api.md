# 单聊数据与 Fake 契约

```text
ConversationRef    refId, generation
MessageRef         refId, generation
ShareIntentRef     refId, generation, kind(forward|businessCard), expiresAt

ChatMessage
  messageId?
  clientMessageId
  conversationRef
  senderMemberRef
  kind
  contentProjection
  quoteProjection?
  createdAt?
  localCreatedAt
  serverSequence?
  deliveryState
  messageVersion
```

```text
ChatRepository
  loadConversation(conversationRef, generation)
  loadHistory(conversationRef, beforeCursor?, generation)
  sendText/sendMedia/sendForward/sendBusinessCard(...clientMessageId, idempotencyKey)
  retry(clientMessageId)
  markRead(conversationRef, readThroughMessageId, idempotencyKey)
  deleteForMe(messageRef, expectedVersion, idempotencyKey)
  revoke(messageRef, expectedVersion, idempotencyKey)
  searchForMe(conversationRef, query, cursor?)
  updateSettings(conversationRef, patch, expectedVersion, idempotencyKey)
  clearForMe(conversationRef, expectedVersion, idempotencyKey)

ChatMediaPort
  pick(kind) -> LocalMediaRef
  createUploadIntent(localMetadata) -> UploadIntentRef
  upload(intent, localRef) -> UploadedMediaRef
  commit(uploadedRef) -> ChatMediaRef
```

- 文本去首尾空白后 1～2000 字；空白消息不发送。
- 短视频当前建议最长 60 秒；图片/视频大小、格式和内容安全由版本化媒体策略返回。
- quote/forward 只保存清洗投影，不允许客户端伪造原作者或直接泄露原始 payload。
- 真实 API、游标和上传协议尚未设计，UI 只依赖 port/Fake。
