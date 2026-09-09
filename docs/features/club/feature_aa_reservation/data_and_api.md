# 一起玩 AA 数据与 Fake 契约

## 2026-09-09 支付兼容修复

共享支付数据源整改同时覆盖 AA 的已有付费出口：由 Fake 登记本次套餐、营业日、抵扣和同一订单引用，支付/详情注入同一个仓库，不能退回另一份默认订单。当前共享展示模型沿用整数元的旧 UI Mock 限制；AA 适配显式拒绝非整元样例，禁止静默截断。未来 Money 仍必须按下文整数分契约实现，真实接入继续阻断。零现金确认、准入与分桌状态不属于本批闭环验收。

```text
ServiceDay
  serviceDate
  displayLabel
  salesOpenAt / salesCloseAt
  eventStartAt / eventEndAt
  zoneId
  availabilityState

AaOfferSummary
  offerRef
  serviceDay
  packageName
  capacityLabel
  remainingBucket
  priceFrom: Money
  promotionLabel?
  availabilityState
  ruleSummary[]

AaQuote
  quoteRef
  quoteRevision
  expiresAt
  offerProjection
  lineItems[]
  eligibleDeductions[]
  selectedDeductions[]
  payable: Money
  termsSnapshotRef
  allowedActions[]

Money
  currency = CNY
  minorUnits: integer

AaReservationProjection
  orderRef
  serviceDay
  status
  paymentIntentRef?
  holdExpiresAt?
  admissionRef?
  assignmentState: pending | revealed
  revealAt
  tableLabel?        # 仅 revealed 可返回
  allowedActions[]
```

```text
AaReservationRepository
  loadLanding(initialServiceDate?, generation)
  selectServiceDay(serviceDate, generation)
  loadOffer(offerRef, generation)
  createQuote(offerRef, idempotencyKey)
  requote(quoteRef, quoteRevision, deductionSelectionRefs, idempotencyKey)
  createReservation(quoteRef, quoteRevision, termsSnapshotRef, idempotencyKey)
  reconcileSubmission(idempotencyKey)
  loadReservation(orderRef, generation)
```

## 契约规则

- 认证身份来自会话；请求不接受 `userAccount`、性别、年龄、奖励、可信金额或桌位 JSON。
- 金额只用整数分，UI 不做浮点计价；每次抵扣变化均请求 Fake/未来服务端重新报价。
- `offerRef/quoteRef/orderRef` 为服务端签发或 App 内 Store 映射的不透明引用。
- `quoteRevision + expiresAt` 防止旧报价提交；创建预订必须携带稳定幂等键。
- `remainingBucket` 建议只返回 `available | fewLeft | soldOut`，不暴露精确同桌人数与成员资料。
- `termsSnapshotRef` 绑定当次退款、迟到、着装、安全和入场规则版本。
- offer 和 quote 不得携带可见卡座号。`assignmentState != revealed` 时，预订、订单、支付和通知投影的 `tableLabel` 必须为空。
- `revealAt` 由服务端按门店时区和营业日规则生成；客户端不用本机时间计算揭晓资格。
- UI Mock 阶段只实现此 port 的 Fake，不设计或调用旧超级接口 ID。
