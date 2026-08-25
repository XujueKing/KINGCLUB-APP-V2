# 订单中心数据与 Fake 契约

## 路由引用

- `OrderRef { opaqueId }`
- 筛选器不是路由身份参数，不携带 userAccount。

## 展示模型

- `OrderSummaryView`：OrderRef、类型、标题、创建时间、金额、状态、场次/桌位摘要
- `OrderDetailView`：权威行项目、费用、支付摘要、状态历史、allowedActions、支持信息
- `OrderAction`：pay、cancel、viewAdmission、viewParty、contactSupport、refresh

## UI 阶段 ports

- `OrderQueryPort.list(filter, cursor)`
- `OrderQueryPort.detail(orderRef)`
- `OrderActionPort.cancel(orderRef, expectedVersion, idempotencyKey)`
- `OrderActionPort.reconcile(idempotencyKey)`

分页使用稳定 cursor；Fake 必须覆盖重复页、空页和刷新后状态变化。页面不得直接调用旧接口编号。
