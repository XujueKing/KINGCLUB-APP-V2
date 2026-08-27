# 好友申请列表页状态

| 状态 | UI | 恢复动作 |
|---|---|---|
| `initialLoading` | 列表骨架 | 等待 |
| `ready` | 混合方向与状态列表 | 刷新/分页 |
| `empty` | 暂无申请 | 添加好友 |
| `loadingMore` | 保留列表 | 等待 |
| `partialError` | 保留首屏 + 底部重试 | 重试 |
| `offlineCached` | 只读缓存 + 更新时间 | 重试 |
| `fatalError` | 全页错误 | 重试/返回 |
| `sessionInvalid` | 清空列表 | 全局 reset |
| `friendAcceptedMock` | 记录变为“已添加”并显示完成提醒 | 发消息/完成 |
| `acceptedReadyToChat` | 已添加记录详情只显示“发消息” | 进入单聊/返回 |

状态标签只能来自稳定枚举；相同 requestRef 不重复；新状态可覆盖旧状态，旧版本不能倒退。
