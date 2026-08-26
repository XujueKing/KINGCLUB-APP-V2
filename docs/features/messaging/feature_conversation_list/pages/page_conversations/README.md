# 会话列表页

- Scope ID：`KC-P-022`
- 文档状态：`Approved for Development`
- 所属功能：[会话列表](../../README.md)
- 路由：`ConversationsRoute`，`/messages`，protectedShell/messages 分支根
- 设计版本：`Legacy Conversations Replica v1`
- UI 状态：`Implemented & Device Verified`（2026-08-26，离线 Mock）
- 最后更新：2026-08-26

## 用户任务与线框

查看系统通知和单聊摘要，识别未读消息并进入正确会话。

```text
消息
[消息] [通讯录]                     [添加好友]
[搜索会话名称____________________________]

[KINGCLUB] 系统通知              3   10:20
           订单状态已更新

置顶
[头像] 好友备注                    2   09:10
       [图片]

最近
[头像] 好友昵称                    ·   昨天
       你收到一条新消息
```

- 列表只含系统通知和单聊；免打扰未读用非数字弱提示，普通未读显示 1～99+。
- 右滑/更多提供无障碍等价菜单：“标记已读/未读”“从列表隐藏”。
- 不显示在线状态、手机号、账号或完整消息正文。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。

## 当前复刻决策

- 用户于 2026-08-26 提供旧版聊天截图，确认保留现有通讯录主体，并在顶部相邻增加 `聊天` 选项。
- 当前 UI 以 [旧版聊天列表 UI 复刻规范](legacy_ui_replication.md) 为准；原线框作为后续扩展场景保留。
- 本轮只使用固定 Fake 会话，不连接 WebSocket、超级接口或真实消息存储。
- Android API 37 模拟器已验证通讯录/聊天双向切换、置顶折叠、Fake 会话预览和消息底栏选中态；验收截图见 [android_chat_mock_latest.png](android_chat_mock_latest.png)。
