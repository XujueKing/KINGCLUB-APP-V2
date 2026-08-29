# 一起玩 AA 预订页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 标题、日期与卡片骨架，禁用操作 |
| `readyAvailable` | 日期、可订套餐、推荐入口 |
| `readyWithPendingPayment` | 顶部待支付卡；同日新订禁用 |
| `readyWithConfirmed` | 顶部旧版紫色定位卡；整卡进入二维码凭证页；同日新订禁用 |
| `salesNotOpen` | 开售时间说明，无购买按钮 |
| `salesClosed` | 截止说明与其他日期入口 |
| `emptyNoSession` | 当日无 AA 场次 |
| `soldOut` | 套餐只读售罄，可刷新/换日 |
| `maintenance` | 写入口关闭，已有订单仍可查看 |
| `offlineCached` | 明确“离线快照”，禁止进入确认 |
| `partialError` | 保留日期/缓存卡片并提供局部重试 |
| `fatalError` | 稳定错误、重试与返回 |
| `sessionInvalid` | 清理敏感引用并 reset 到鉴权 |

切日期请求使用 SingleFlight；旧日期或旧 generation 的迟到响应不得覆盖当前选中日期。
