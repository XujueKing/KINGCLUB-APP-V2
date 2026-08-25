# 一起玩 AA 数据与 Fake 契约

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
  tableLabel
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
- UI Mock 阶段只实现此 port 的 Fake，不设计或调用旧超级接口 ID。
