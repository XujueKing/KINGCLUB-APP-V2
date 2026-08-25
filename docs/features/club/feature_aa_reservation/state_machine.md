# 一起玩 AA 状态机

## 预订聚合状态

```text
none
  -> submitting
  -> pendingPayment(expiresAt)
  -> confirmed
  -> completed

submitting -> resultUnknown -> pendingPayment | confirmed | rejected
pendingPayment -> confirmed | expired
confirmed -> cancelledByVenue | completed
```

| 状态 | 含义 | 客户端允许动作 |
|---|---|---|
| `none` | 当天没有有效预订 | 浏览并发起确认 |
| `submitting` | 创建占位请求进行中 | 禁止重复提交 |
| `resultUnknown` | 请求超时但结果未知 | 只允许用原幂等键对账 |
| `pendingPayment` | 席位已短时占位 | 在 `expiresAt` 前进入支付 |
| `confirmed` | 服务端确认付款/免付并锁定席位 | 查看订单/后续凭证 |
| `expired` | 未及时支付，占位释放 | 刷新库存后重新选择 |
| `rejected` | 资格、库存、价格或规则校验拒绝 | 展示稳定原因并返回刷新 |
| `cancelledByVenue` | 场地方取消 | 查看订单和后续处理说明 |
| `completed` | 已完成入场/消费 | 只读查看订单 |

## 报价状态

```text
loading -> ready(revision, expiresAt)
ready -> refreshing -> ready(new revision)
ready -> stale | submitting
submitting -> accepted | priceChanged | soldOut | ineligible | resultUnknown
```

- 客户端倒计时只用于提示；服务端时间和状态是唯一权威。
- `priceChanged` 必须展示新旧差异并要求用户重新确认，不得静默提交。
- `soldOut`、`ineligible`、`duplicateActiveReservation` 不得自动换套餐或替用户接受规则。
- 支付 SDK 返回成功不等于 `confirmed`；最终状态由 KC-P-038 对账后决定。
