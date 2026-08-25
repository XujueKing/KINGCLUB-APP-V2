# AA 卡座套餐详情页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 主图、标题、内容和底栏骨架 |
| `ready` | 完整详情与“继续” |
| `fewLeft` | 少量提示，但不制造虚假倒计时 |
| `priceUpdated` | 标明价格已更新，用户确认后继续 |
| `soldOut` | 详情只读，继续按钮改为返回列表 |
| `salesClosed` | 显示截止原因与其他日期入口 |
| `ineligible` | 显示稳定资格说明，无继续动作 |
| `imageError` | 占位图，正文仍可用 |
| `offlineCached` | 缓存详情只读，禁用继续 |
| `fatalError` | 重试/返回，不用路由快照拼页面 |
| `invalidRef` | 清除 AaOfferRef 并安全返回列表 |
| `sessionInvalid` | 清理引用并 reset |

未知 `availabilityState` 一律只读降级，不默认视为可订。
