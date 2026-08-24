# 好友申请列表页

- Scope ID：`KC-P-016`
- 文档状态：`In Review`
- 所属功能：[好友申请与添加](../../README.md)
- 路由：`FriendRequestsRoute`，`/social/requests`，protectedShell/messages 子路由
- 设计版本：`Friendship Wireframe v1 / Requests`
- 最后更新：2026-08-25

## 用户任务与线框

查看收到和发出的好友申请及其权威状态，再进入统一用户主页查看详情或处理。

```text
[返回]              好友申请             [添加]

[头像] 昵称  收到 · 来自当面扫码
       验证消息预览                    [待处理 >]
[头像] 昵称  发出 · 2小时前
       我的验证消息                    [等待中 >]
[头像] 昵称  收到 · 昨天                 [已拒绝 >]
```

- 单列表按 `updatedAt` 倒序，以“收到/发出”和状态文字区分，不增加 Tab。
- 不显示永久账号；来源只展示稳定类别。
- 列表不提供滑动接受/拒绝，避免误触；处理在用户主页完成。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
