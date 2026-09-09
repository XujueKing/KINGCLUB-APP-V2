# 扫码点单数据与 Fake 契约

## 路由引用

- `OrderingContextRef { opaqueId }`
- `CartDraftRef { opaqueId }`
- `QuoteRef { opaqueId, version, expiresAt }`

## 展示模型

- `OrderingContextView`：门店名、桌位显示名、场次、有效状态
- `CatalogSectionView`：分类和商品卡片
- `ProductView`：名称、图片、规格、可售标签、服务端展示价
- `CartLineDraft`：productId、optionIds、quantity、备注（受限）
- `QuoteView`：行项目、优惠、费用、总额、到期时间、差异提示

## UI 阶段 ports

- `OrderingContextPort.resolve(ref)`
- `CatalogPort.load(contextRef)`
- `CartDraftPort.load/save/clear(...)`
- `QuotePort.create(contextRef, cartDraft)`
- `OrderCreationPort.create(quoteRef, idempotencyKey)`
- `OrderCreationPort.reconcile(idempotencyKey)`

UI/Mock 阶段全部由 Fake 实现。未来 adapter 只能把这些语义映射到已批准契约，不允许页面直接调用超级接口。

## 2026-09-09 审计修复补充

按[本轮对照与验收条件](../../../audits/2026-09-09-miniprogram-alignment.md)实现：Fake 创建订单须登记完整报价快照和支付意图映射；同一请求幂等，不同请求不得共用固定订单号。金额只在 Fake 数据源计算，确认后跨页只携带引用，不能在支付页替换为默认样例。此临时 Fake 输入不是未来真实接口的可信价格来源。
