# 黑名单页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 列表骨架 |
| `ready` | 黑名单、搜索、分页 |
| `empty` | 无拉黑用户说明 |
| `searchEmpty` | 无匹配、清除搜索 |
| `loadingMore` | 保留列表 + 进度 |
| `confirmingUnblock` | 后果说明 |
| `unblocking` | 对应行进度、防重复 |
| `partialError` | 保留已有列表、局部重试 |
| `offlineCached` | 缓存只读 + 更新时间 |
| `fatalError` | 重试/返回 |
| `sessionInvalid` | 清空并 reset |

解除成功后该项立即移除；旧版本/迟到响应不得把它重新插回。
