# AA 确认订单页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 订单与价格骨架，提交禁用 |
| `quoteReady` | 最新报价、抵扣、规则和提交按钮 |
| `requoteLoading` | 保留旧明细但标记刷新中，禁止提交 |
| `quoteChanged` | 展示差异并要求重新确认规则/金额 |
| `quoteExpired` | 禁止提交，刷新报价或返回详情 |
| `submitting` | 全屏级防重复，返回需提示正在确认 |
| `resultUnknown` | 对账中，只允许继续查询或安全离开 |
| `pendingPayment` | 展示席位占位到期时间并进入 KC-P-038 |
| `confirmedNoCash` | 0 元/全额抵扣后服务端确认，进入订单详情 |
| `soldOut` | 不自动换套餐，返回列表刷新 |
| `duplicateActiveReservation` | 展示已有订单并提供查看入口 |
| `ineligible` | 展示稳定原因并退出写流程 |
| `offline` | 禁止创建/重报价；可返回 |
| `invalidRef` | 清除报价引用并返回详情/列表 |
| `sessionInvalid` | 清空报价、抵扣和幂等上下文并 reset |

离开再回来必须重读 quote/order；不能仅凭本地倒计时恢复可提交状态。
