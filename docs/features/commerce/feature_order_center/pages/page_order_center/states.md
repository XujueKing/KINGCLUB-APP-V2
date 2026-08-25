# 订单中心页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 列表骨架 |
| `content` | 分组/筛选订单 |
| `emptyAll/emptyFilter` | 对应空状态 |
| `refreshing` | 保留列表并更新 |
| `loadingMore/loadMoreError/endReached` | 游标分页状态 |
| `offlineCached` | 标记缓存时间，禁写 |
| `error` | 重试 |
| `sessionInvalid` | 清列表并登录 reset |

未知订单状态仍展示为“状态更新中”，不得丢弃订单。
