# 通讯录页

- Scope ID：`KC-P-014`
- 文档状态：`Approved for Development`
- 所属功能：[通讯录](../../README.md)
- 路由：`ContactsRoute`，`/messages/contacts`，protectedShell/messages 子根
- 设计版本：`Contacts Wireframe v1 / Legacy Contacts Header v1`
- 最后更新：2026-08-28
- UI 状态：`UI Mock Implemented & Device Verified`（离线 Mock）

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

## 当前实现记录

- 已在 App Shell “消息”分支实现 KingClub 好友通讯录，并提供 `/messages/contacts` 类型化入口。
- 用户于 2026-08-26 确认通讯录主体 UI 保持不变；仅在顶部旁边增加“聊天”选项，与 [旧版聊天列表](../../../messaging/feature_conversation_list/pages/page_conversations/legacy_ui_replication.md) 双向切换。
- 用户随后确认顶部本身也按 [旧版通讯录顶部栏](legacy_header_replication.md) 复刻：左侧加号、居中双选项和底部分割线；忽略右侧微信宿主按钮，并移除当前顶部的烧杯/更多按钮。
- 已实现新的朋友、添加好友、黑名单和用户主页的受控内存意图；目标页面尚未实现时只显示明确提示。
- 已实现备注/公开昵称搜索、A-Z/# 分组、右侧索引、下拉刷新、头像占位和申请角标。
- 已实现首次加载、空列表、搜索无结果、离线缓存、加载/分页失败、关系移除和会话失效 Fake 状态。
- 未读取系统通讯录，未展示手机号、实名、永久账号或在线状态。
- Android API 37 模拟器已验证列表、索引和英文昵称搜索；Widget 测试覆盖搜索隐私边界、添加好友与用户主页意图。
- 新增顶部聊天入口后再次完成设备验证，通讯录主体未改；截图见 [android_contacts_chat_toggle_latest.png](android_contacts_chat_toggle_latest.png)。
- 旧版顶部栏复刻已完成设备验收；最新截图见 [android_contacts_legacy_header_latest.png](android_contacts_legacy_header_latest.png)。
- 2026-08-28 正式验收补齐七组独立自动场景；修复 200% 字体下快捷入口卡片底部溢出，并确认搜索不匹配手机号或永久账号。
- 会话失效会清除好友快照和搜索词、停用顶部写入口并交给全局登录重置；未连接真实社交接口。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
