# 系统通知页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 列表骨架 |
| `ready` | 通知列表、展开、动作、全读 |
| `empty` | 暂无通知 |
| `loadingMore` | 保留首屏 + 进度 |
| `markingRead` | 单卡/全局进度，防重复 |
| `partialError` | 保留卡片 + 局部重试 |
| `offlineCached` | 缓存只读 + 更新时间 |
| `unknownProjection` | 通用只读卡片，无动作 |
| `targetUnavailable` | 保留通知 + 稳定说明 |
| `fatalError` | 重试/返回 |
| `sessionInvalid` | 清空并 reset |

ACK、isRead 和业务状态互相独立；未知 action/category 必须失败关闭。

## UI Mock 联动状态

| 状态 | UI/动作 |
|---|---|
| `threeUnread` | 三张卡片有未读边框/红点，会话行显示 `3` |
| `partialRead` | 展开一张后剩余数递减，会话行返回后显示剩余数量 |
| `allRead` | 全部卡片移除未读强调，会话行不显示红点 |
| `reopenPreserved` | 当前 App Shell 生命周期内再次进入时保留剩余未读数 |
