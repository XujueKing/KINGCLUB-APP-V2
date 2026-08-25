# 钱包与流水数据和 Fake 契约

## 引用与展示模型

- `AssetType = cashBalance | goldCoin | diamond`
- `AssetSummaryView`：type、available、frozen?、pending?、unit、asOf
- `LedgerEntryRef { refId, generation }`
- `LedgerEntryView`：类型、方向、整数金额、标题、时间、状态、关联 OrderRef?、冲正关联?
- `LedgerPage { entries, nextCursor, asOf }`

## UI 阶段 ports

- `AssetLedgerPort.loadSummary()`
- `AssetLedgerPort.loadFirst(assetType, period)`
- `AssetLedgerPort.refresh(assetType, period)`
- `AssetLedgerPort.loadMore(assetType, period, cursor)`
- `AssetLedgerPort.resolveOrder(entryRef)`

Fake 必须分别模拟三种单位、pending/reversed、游标重复、摘要与列表时间差。未来 adapter 不允许页面传 userAccount，也不允许用流水在客户端重建余额。
