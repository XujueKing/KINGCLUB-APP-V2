# 通讯录页

- Scope ID：`KC-P-014`
- 文档状态：`Approved for Development`
- 所属功能：[通讯录](../../README.md)
- 路由：`ContactsRoute`，`/messages/contacts`，protectedShell/messages 子根
- 设计版本：`Contacts Wireframe v1`
- 最后更新：2026-08-25

## 用户任务与导航

查找已有好友，查看新申请或进入添加好友、黑名单和统一用户主页。入口为消息分支顶部“通讯录”；返回由 Shell 处理。联系人使用内存 `SocialTargetRef`，无外部打开。

## 线框

```text
通讯录                         [更多]
[搜索备注或昵称________________]
[新的朋友              2] [添加好友]

A
[头像] Alice / 我的备注                     >
B
[头像] Bob                                   >
                                      A B C … #
```

- 更多菜单仅含“黑名单”；会话列表由消息分支切换器进入。
- 空态提供“添加好友”，搜索空态提供“清除搜索”。
- 200% 字体隐藏右侧字母索引并保持列表可滚动；分组标题和认证标识有文字语义。
- 不显示手机号、账号、实名或在线状态。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
