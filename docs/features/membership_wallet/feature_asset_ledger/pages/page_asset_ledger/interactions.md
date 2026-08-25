# 钱包与资产流水页交互

| 触发 | 行为 |
|---|---|
| 页面进入/恢复 | 查询 supportedAssets、摘要和默认资产首屏 |
| 切换资产 | 使用独立 cursor/状态，不换算单位 |
| 切换月份 | 重置当前资产 cursor 并加载 |
| 下拉刷新 | 摘要与首屏同一批次替换 |
| 滚动到底 | 单次加载 nextCursor，entryRef 去重 |
| 点关联订单 | resolveOrder(entryRef) 后 openOrderDetail(OrderRef) |
| 点普通流水 | 当前页展开标题、时间、状态摘要 |
| App 后台 | 隐私遮盖；恢复后重读 |
| 会话失效 | 清除摘要、流水、cursor 并 reset |

不支持长按复制余额、流水引用或技术字段；埋点不记录任何资产数值。
