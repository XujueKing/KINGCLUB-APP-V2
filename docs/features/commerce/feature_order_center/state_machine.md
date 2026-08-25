# 订单状态与动作模型

## 消费者状态族

| 状态 | 含义 | 常见动作 |
|---|---|---|
| `awaitingPayment` | 已创建，待完成支付 | pay、cancel（若允许） |
| `paymentProcessing` | 支付结果确认中 | refresh |
| `confirmed` | 已支付或免付确认 | viewAdmission（若开放） |
| `inService` | 已入场/履约中 | viewDetail |
| `completed` | 履约完成 | viewDetail |
| `cancelled` | 已取消 | viewDetail |
| `refunding` | 退款处理中 | contactSupport |
| `refunded` | 已退款 | viewDetail |
| `disputed` | 异常或申诉处理中 | contactSupport |

`allowedActions` 才是动作权威；上表仅用于设计说明。未知状态只读并允许刷新/联系客服。

## 关键规则

- 支付结果由支付回调和服务端查询确认。
- 取消使用 expectedVersion + IdempotencyKey，超时对账。
- 列表推送只触发重读，不直接改状态。
- 金额使用服务端返回的最小货币单位；退款金额与原支付分开显示。
