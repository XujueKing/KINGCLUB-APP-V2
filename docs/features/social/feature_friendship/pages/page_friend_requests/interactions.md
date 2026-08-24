# 好友申请列表页交互

- 点击记录发出 `openUserProfile(requestRef)`，详情重新读取权威状态。
- 点击添加发出 `openAddFriend`；下拉和分页均 SingleFlight。
- 从详情返回后按 requestVersion 更新或移除过期记录，不本地猜测状态。
- WebSocket 事件只触发失效标记/刷新，不直接插入含敏感正文的新记录。
- 离线缓存只读，不能在列表内接受、拒绝或重发申请。
