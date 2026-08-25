# 钱包与资产流水页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 摘要和流水骨架，不闪旧金额 |
| `content` | 启用资产卡与当前流水 |
| `zeroAssets` | 显示权威 0 和说明 |
| `emptyLedger` | 当前资产/月份无记录 |
| `refreshing` | 原子更新摘要与首屏 |
| `loadingMore/loadMoreError/endReached` | cursor 分页 |
| `pending/reversed` | 条目状态明确 |
| `offlineCached` | 显示 asOf，只读 |
| `unknownAsset/status` | 安全通用显示 |
| `privacyCovered/sessionInvalid` | 遮盖或登录 reset |

摘要失败时不得拿本地流水求余额。
