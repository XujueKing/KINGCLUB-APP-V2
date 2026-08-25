# 单聊详情页

- Scope ID：`KC-P-025`
- 文档状态：`Approved for Development`
- 所属功能：[稳定单聊](../../README.md)
- 路由：`DirectChatDetailsRoute`，`/messages/chat/details`，`$extra: ConversationRef`
- 设计版本：`Direct Chat Wireframe v1 / Details`
- 最后更新：2026-08-25

## 用户任务与线框

查看对方、调整当前单聊设置、搜索聊天记录，或为自己清空记录。

```text
[返回]              单聊详情

[头像] 好友备注 / 公开昵称                    >

消息免打扰                              [开关]
置顶聊天                                [开关]
搜索聊天记录                                >
关系权限                                    >

[为我清空聊天记录]
```

- 不含群成员、加减成员、群二维码、群公告、群管理、聊天背景或退出群聊。
- 搜索在当前页面进入内嵌 search mode，不新增逻辑页面；只搜索本人仍可见的文本投影。
- clearForMe 对当前用户隐藏服务端游标之前的历史，对方不受影响；不可恢复，需二次确认。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
