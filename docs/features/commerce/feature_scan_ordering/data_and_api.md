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
