# 会话列表页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 固定切换/通知入口 + 列表骨架 |
| `ready` | 置顶与最近会话、刷新/分页 |
| `empty` | 系统通知入口 + 去通讯录 |
| `searching` | query 与结果进度 |
| `searchEmpty` | 清除搜索 |
| `loadingMore` | 保留首屏 + 底部进度 |
| `actionPending` | 单行已读/隐藏进度 |
| `partialError` | 保留可用列表 + 局部重试 |
| `offlineCached` | 缓存 + 更新时间，只读 |
| `fatalError` | 重试/切通讯录 |
| `sessionInvalid` | 清空并 reset |

同一 conversationRef 只出现一次；summaryVersion、serverSequence 和 unread 不得倒退。
