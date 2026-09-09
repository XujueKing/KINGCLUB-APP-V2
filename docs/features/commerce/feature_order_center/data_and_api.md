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

## 2026-09-09 审计修复补充

按[本轮对照与验收条件](../../../audits/2026-09-09-miniprogram-alignment.md)实现：新建点单与支付、取消共享进程内 Fake 数据源；详情及列表重进后保留同一商品、金额、状态。未知引用不能映射任意可支付订单。历史只读售后样例保留，但不得覆盖新建订单记录。
