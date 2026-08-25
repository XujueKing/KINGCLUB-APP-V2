# 联系人选择页

- Scope ID：`KC-P-026`
- 文档状态：`Approved for Development`
- 所属功能：[稳定单聊](../../README.md)
- 路由：`ContactSelectorRoute`，`/messages/select-contact`，`$extra: ShareIntentRef`
- 设计版本：`Direct Chat Wireframe v1 / Selector`
- 最后更新：2026-08-25

## 用户任务与线框

为一条转发消息或已批准业务卡片选择一个好友，预览目标后明确确认发送。

```text
[取消]              选择联系人
[搜索备注或昵称____________________________]

[头像] 好友备注                                  >
[头像] 好友昵称                                  >

选择后确认层：
发送给 [头像] 好友备注
[转发消息/业务卡片清洗预览]
[取消]                                      [发送]
```

- 只列当前允许单聊的好友，一次只能选一个；不支持多选、群发或群会话。
- ShareIntentRef 只在内存中存在且有过期时间，不把原消息/订单完整对象放路由。
- 业务卡片发送前重新验证对象状态；转发创建清洗副本，不泄露原始 payload。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
