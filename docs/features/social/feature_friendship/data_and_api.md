# 好友申请数据与 Fake 契约

```text
SocialTargetRef      refId, generation, expiresAt?
FriendRequestRef     requestRefId, generation
FriendRequestSummary requestRef, direction, displayName, avatarRef?, messagePreview,
                     sourceCategory, status, updatedAt, requestVersion
FriendRequestDetail  summary, targetRef, fullMessage, allowedActions[]
```

状态：`incomingPending | outgoingPending | accepted | rejected | expired | cancelled`。
来源只用稳定类别：`qrInPerson | profile | contacts | unknown`，不展示自由服务端原文。

```text
FriendshipRepository
  listRequests(cursor?, filter?, generation)
  loadRequest(requestRef, generation)
  prepareInvitePreview(friendInviteToken, generation)
  sendRequest(targetRef, message, privateRemark?, idempotencyKey, generation)
  acceptRequest(requestRef, expectedVersion, idempotencyKey, generation)
  rejectRequest(requestRef, expectedVersion, idempotencyKey, generation)
```

- 验证消息 0～80 字；私有备注 0～24 字，仅本人可见。
- token 只交给 Repository 换取 `SocialTargetRef`，不进入路由、日志、缓存或埋点。
- 真实超级接口和 WebSocket 事件名尚未设计；UI 只依赖上述 port 和 Fake。
