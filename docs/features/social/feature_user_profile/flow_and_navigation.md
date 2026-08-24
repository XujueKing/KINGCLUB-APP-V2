# 用户主页关系状态与导航

```text
relationshipState
  self | stranger | incomingPending | outgoingPending |
  friend | blockedByMe | unavailable
```

| 状态 | 主动作 | 次动作 |
|---|---|---|
| self | 返回我的主页 | 无 |
| stranger | 发送好友申请 | 返回 |
| incomingPending | 接受 | 拒绝 |
| outgoingPending | 等待对方确认 | 无 |
| friend | 发消息 | 好友备注、关系权限 |
| blockedByMe | 查看有限资料 | 进入权限页解除拉黑 |
| unavailable | 无 | 返回 |

- 入口可来自通讯录、申请列表或短期二维码预览，统一转换为进程内 `SocialTargetRef`/`FriendRequestRef`。
- `UserProfileRoute` 建议 `/social/profile`，使用 `$extra`，禁止外部打开、URI 参数和进程恢复。
- 页面每次恢复可按 `profileVersion/relationshipVersion` 刷新，动作前再次校验 allowedActions。
- self、非法引用、过期预览和权限变化都必须稳定收口，不显示服务端内部原因。
