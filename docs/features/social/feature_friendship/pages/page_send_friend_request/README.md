# 发送好友申请页

- Scope ID：`KC-P-018`
- 文档状态：`Approved for Development`
- 所属功能：[好友申请与添加](../../README.md)
- 路由：`SendFriendRequestRoute`，`/social/request/send`，`$extra: SocialTargetRef`
- 设计版本：`Friendship Wireframe v1 / Send`
- 最后更新：2026-08-25

## 用户任务与线框

向已预览确认的目标发送一条验证消息，并可预设仅自己可见的好友备注。

```text
[返回]            申请添加好友                 [发送]

[头像] 公开昵称
验证消息（0/80） [我是___________]
好友备注（选填） [_______________]  仅自己可见

对方接受后才会成为好友
```

- 路由不含账号或消息；失效 targetRef 返回安全来源。
- 验证消息 0～80 字，私有备注 0～24 字；控制字符拒绝，空消息允许。
- 页面不自行发送 WebSocket；成功通知由服务端负责。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
