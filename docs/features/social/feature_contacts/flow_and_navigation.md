# 通讯录流程与导航

```text
Messages Tab -> ContactsRoute
  ├─ new requests -> FriendRequestsRoute
  ├─ add friend -> AddFriendRoute
  ├─ contact -> UserProfileRoute(SocialTargetRef)
  ├─ blacklist -> BlacklistRoute
  └─ conversation switch -> ConversationsRoute
```

- `ContactsRoute` 是 protectedShell/messages 下的通讯录子根，location 建议 `/messages/contacts`，无 URI 参数。
- 联系人点击只传进程内、带 generation 的 `SocialTargetRef`；丢失或过期时留在通讯录并提示重新选择。
- 从用户主页返回时按 `relationshipVersion` 局部刷新；好友已删除或被拉黑时立即从正常列表移除。
- 会话失效统一 reset，不保留搜索词、联系人快照或返回栈。
