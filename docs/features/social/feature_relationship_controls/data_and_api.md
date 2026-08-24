# 关系控制数据与 Fake 契约

```text
FriendRemark       alias?, privateNote?, remarkVersion
RelationshipRules accessMode(standard|messagesOnly)
                  hideMyContentFromThem
                  hideTheirContentFromMe
                  blockedByMe
                  relationshipVersion
BlockedMember      targetRef, displayName, avatarRef?, blockedAt, relationshipVersion
```

```text
RelationshipRepository
  loadRemark(targetRef, generation)
  updateRemark(targetRef, patch, expectedVersion, idempotencyKey, generation)
  loadRules(targetRef, generation)
  updateRules(targetRef, patch, expectedVersion, idempotencyKey, generation)
  deleteFriend(targetRef, expectedVersion, idempotencyKey, generation)
  block(targetRef, expectedVersion, idempotencyKey, generation)
  unblock(targetRef, expectedVersion, idempotencyKey, generation)
  listBlocked(cursor?, query?, generation)
```

- 私有备注不展示给对方，也不进入通知、搜索日志或分析事件；搜索可在授权服务端投影中匹配 alias。
- 可见性规则只影响产品层允许内容；服务端仍对每次内容/消息读取执行授权。
- Fake 覆盖冲突、重复命令、结果未知、跨页刷新、离线只读和会话失效。
