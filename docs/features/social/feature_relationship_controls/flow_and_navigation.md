# 关系控制流程与状态机

```text
UserProfile(friend)
  ├─ FriendRemarkRoute -> save patch -> return version
  └─ RelationshipPermissionsRoute
       ├─ update visibility/access mode
       ├─ block (confirm) -> blockedByMe -> profile/list refresh
       └─ delete friend (confirm) -> stranger -> safe return

BlacklistRoute
  -> UserProfile(blockedByMe)
  -> unblock (confirm) -> stranger
```

- 每个页面只接收进程内 `SocialTargetRef`，不得在 URI 放账号、手机号或 conversationId。
- 设置保存采用 expected `relationshipVersion`；版本冲突重新读取并让用户确认，不静默覆盖。
- 拉黑/删除/解除拉黑均为幂等命令；结果未知时查询权威状态。
- 会话设置和聊天历史不在关系命令中隐式修改。
