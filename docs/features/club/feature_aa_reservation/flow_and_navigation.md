# 一起玩 AA 流程与导航

## 主流程

```text
Home / Order Center
  -> AaReservationsRoute
  -> 选择 serviceDate
  -> 选择可订套餐或系统推荐
  -> AaPackageDetailRoute(AaOfferRef)
  -> 继续
  -> AaOrderConfirmationRoute(AaQuoteRef)
  -> 选择允许的抵扣并刷新权威报价
  -> 确认规则 + 幂等提交
  -> pendingPayment + expiresAt
  -> PaymentRoute(PaymentIntentRef) [KC-P-038，待其批准]
  -> OrderDetailRoute(OrderRef) / AaPositioningCardRoute(AdmissionRef)
```

## 返回与恢复

- KC-P-027 返回原来源；切日期保留在同一页面，不叠加路由。
- KC-P-028 返回列表并保留选中日期与滚动位置；不得把已加载报价当成回退后的最新库存。
- KC-P-029 未提交时返回详情；若抵扣选择已变化，只丢弃本地选择，不取消任何订单。
- 提交成功后不得简单 pop 回详情重复提交；转入支付或订单详情。
- 提交结果未知时进入 `reconciling`，用同一幂等键查询结果；禁止重新生成订单。
- 席位占位过期后返回确认页失效状态，再回详情/列表刷新。

## 已有预订分流

| 权威状态 | 动作 |
|---|---|
| `pendingPayment` 且未过期 | 继续支付；若 KC-P-038 尚未批准，Mock 阶段展示“支付流程待开放” |
| `confirmed` + `assignmentPending` | 显示“卡座待揭晓”和揭晓时间；不显示卡座号，不开放定位凭证 |
| `confirmed` + `assignmentRevealed` | 仅在营业日前一天起显示旧版紫色定位卡；点击进入 `AaPositioningCardRoute` |
| `completed` | 进入订单详情只读 |
| `expired | cancelled` | 显示结果与刷新入口，不占用当天名额 |
| 未知新状态 | 安全只读，刷新/联系客服，不猜测动作 |

## 路由约束

```text
AaOfferRef       refId, generation, expiresAt
AaQuoteRef       refId, generation, quoteRevision, expiresAt
OrderRef         refId, generation
PaymentIntentRef refId, generation, expiresAt
AdmissionRef     refId, generation, expiresAt?
```

- 路由只传进程内不透明引用，不传日期、账号、性别、套餐 JSON、库存或金额。
- 暂不开放外部深链。通知进入订单/票据时必须先通过业务 API 重读对象。
- 下游页面未批准前，RouteIntent 只作为契约占位，不创建页面或通用成功页。
- AA 定位凭证页只消费不透明 `AdmissionRef`；只有服务端投影返回 `assignmentRevealed` 且当前时间到达 `revealAt` 后才允许打开。本地 Mock 使用固定已揭晓投影，二维码内容不包含手机号、姓名或可复用生产凭据。
