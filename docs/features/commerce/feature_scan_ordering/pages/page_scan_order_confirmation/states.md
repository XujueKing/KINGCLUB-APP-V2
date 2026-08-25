# 点单确认页状态

| 状态 | UI/动作 |
|---|---|
| `loadingQuote` | 订单骨架，无提交 |
| `ready` | 权威明细与提交按钮 |
| `quoteExpiring` | 倒计时提示 |
| `quoteExpired` | 禁止提交，刷新报价 |
| `quoteChanged` | 差异卡片与重新确认 |
| `soldOut/limitExceeded` | 返回购物车修正 |
| `submitting` | 单次提交，禁重复 |
| `resultUnknown` | 对账中，不新建订单 |
| `orderCreated` | 导向支付处理 |
| `offline/sessionInvalid` | 禁止提交并安全恢复 |

客户端不得根据按钮回调自行进入成功状态。
