# 会话列表页交互

- 点击单聊发出 `openDirectChat(ConversationRef)`；点击系统通知发出 `openSystemNotifications`。
- 切换通讯录发出 `openContacts`，不创建新的 Shell 分支。
- 搜索 300ms 防抖，只匹配显示名；清空恢复完整列表。
- 标记已读/未读和隐藏均使用 expectedVersion、幂等键与 SingleFlight。
- 下拉/分页失败保留已有摘要；WebSocket 事件先去重再触发 Repository 合并/补拉。
- 重复点击当前消息入口回顶；会话引用失效时留在列表并刷新。
