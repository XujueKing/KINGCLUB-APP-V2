# 单聊页

- Scope ID：`KC-P-024`
- 文档状态：`Approved for Development`
- 所属功能：[稳定单聊](../../README.md)
- 路由：`DirectChatRoute`，`/messages/chat`，`$extra: ConversationRef`
- 设计版本：`Direct Chat Wireframe v1 / Chat`
- 最后更新：2026-08-25

## 用户任务与线框

查看单聊历史，可靠发送文本、图片、短视频、引用或批准的分享内容，并理解每条消息的发送状态。

```text
[返回]         好友备注 / 公开昵称            [详情]
                 [关系变化提示]

       [更早消息加载中]
[对方] 文本消息
              [我] 图片缩略图          已读
[撤回了一条消息]
[我] 发送失败                              [重试]

[引用：好友 · 原消息摘要]
[＋] [输入消息____________________] [发送]
```

- 头像/标题进入用户主页，详情按钮进入 KC-P-025。
- “＋”只提供图片、短视频和已批准业务卡片；无红包、金币、礼物、文件或位置。
- 关系结束时保留历史只读并禁用输入；不把错误伪装成“对方拒收”。
- 200% 字体下消息气泡限制最大宽度但可纵向扩展；状态和失败动作可由读屏理解。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
