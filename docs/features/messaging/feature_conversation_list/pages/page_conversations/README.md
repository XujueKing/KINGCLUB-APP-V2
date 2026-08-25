# 会话列表页

- Scope ID：`KC-P-022`
- 文档状态：`Approved for Development`
- 所属功能：[会话列表](../../README.md)
- 路由：`ConversationsRoute`，`/messages`，protectedShell/messages 分支根
- 设计版本：`Conversations Wireframe v1`
- 最后更新：2026-08-25

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
