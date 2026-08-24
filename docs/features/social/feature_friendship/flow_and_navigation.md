# 好友申请流程与状态机

```text
AddFriendRoute
  ├─ openSafeScanner(friendInvite)
  │    -> UserProfileRoute(invitePreviewRef)
  │         -> SendFriendRequestRoute(targetRef)
  └─ openPersonalQr

FriendRequestsRoute
  -> UserProfileRoute(requestRef)
       ├─ incomingPending: accept / reject
       ├─ outgoingPending: read only
       └─ terminal/friend: show authority result
```

```text
none -> outgoingPending -> accepted | rejected | expired | cancelled
none -> incomingPending -> accepted | rejected | expired
accepted -> friendship
```

- 服务端状态是权威；客户端不能根据本地按钮点击直接构造 friendship。
- 接受、拒绝、发送均使用 SingleFlight + 幂等键；结果未知时查询申请/关系版本，不盲目重发。
- 同时互发、对方先接受、目标被封禁、码过期等竞态均转为最新稳定状态。
- WebSocket 只作为失效提示；收到事件后 Repository 重新读取，不把推送载荷当权威详情。
