# 好友申请列表页

- Scope ID：`KC-P-016`
- 文档状态：`Approved for Development`
- 所属功能：[好友申请与添加](../../README.md)
- 路由：`FriendRequestsRoute`，`/social/requests`，protectedShell/messages 子路由
- 设计版本：`Friendship Wireframe v1 / Requests / Legacy Friend Requests Replica v1`
- 最后更新：2026-08-26
- UI 流程更新：`Friend Accepted → Start Chat Mock（2026-08-27）`

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

## 2026-08-27 好友通过与聊天衔接

- 本期离线 UI Mock 暂在申请详情面板演示“拒绝/接受”，不建立真实好友关系。
- 接受后先显示“已添加好友，现在可以开始聊天”的明确提醒，并把该申请状态更新为“已添加”。
- 提醒中的“发消息”进入该好友的单聊页；单聊页顶部先显示好友建立系统消息，再按时间顺序展示双方消息。
- 返回“新的朋友”后保留本地“已添加”状态；重复打开该记录只显示“发消息”，不再重复接受。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。

## 2026-08-26 旧版复刻变更

本轮按 [旧版“新的朋友”UI 复刻规范](legacy_ui_replication.md) 开发离线 UI Mock。首屏使用 2 条 Fake 申请与通讯录入口角标保持一致；不接真实服务。
