# 会话列表旧版审计

- 文档状态：`Approved for Development`
- 审计基线：`KingClub-app master / 505d222 / 1.1.37`

| 旧实现 | 风险 | V2 取舍 |
|---|---|---|
| `index` chat swiper | 会话、通讯录、群聊和 tabData 混合 | KC-P-022 独立会话根 |
| `S231202503070657` | 服务端摘要再与本地消息库拼接 | 单一 ConversationSummary 投影 |
| conversationsId=0 | 系统通知伪装成普通会话 | 固定 SystemNotifications 入口 |
| 置顶折叠区 | 本地展开状态与服务器排序混合 | 服务端 pinned + lastActivity 排序 |
| 滑动免打扰/隐藏/删除 | 操作语义不清，可能仅改本地 | 列表只做已读/隐藏；设置归详情 |

旧 interfaceId、数字状态和本地缓存结构只作审计证据。
