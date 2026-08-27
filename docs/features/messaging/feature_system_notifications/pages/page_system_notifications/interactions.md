# 系统通知页交互

- 点击/展开未读卡片提交一次 markRead；仅进入页面不自动全部已读。
- “全部已读”先确认范围，再携带 readThroughCursor 和幂等键提交。
- 点击动作产生类型化 `NotificationAction`；Coordinator 只接受已批准目标，目标页重新读取权威状态。
- WebSocket 通知按 eventId 去重并走 cursor 补拉，不直接把事件正文插入列表。
- 分页失败保留已加载卡片；离线不能更改阅读状态。
- 不提供删除、外部 URL、复制订单号或直接支付动作。

## UI Mock 跨页联动

- 页面初始化使用 `initialUnreadCount` 映射三张固定 Fake 卡片的 `read` 状态。
- 未读卡片首次展开时调用 `onUnreadChanged(remainingUnread)`；重复展开/折叠不得重复扣减。
- “全部已读”只在仍有未读卡片时生效，并回调 `onUnreadChanged(0)`。
- 返回会话列表后，KING CLUB 行读取同一 App Shell 内存状态，不自行推测或重算未读数。
