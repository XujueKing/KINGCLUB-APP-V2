# 扫码点单

- Scope ID：`KC-F-027`
- 文档状态：`Approved for Development`
- 所属业务域：`commerce`
- M0 范围：`In Release Scope`
- 设计版本：`Scan Ordering v1`
- 最后更新：2026-08-25

## 目标与用户价值

会员扫描受信任桌码后，确认门店与桌位、选择在售商品，并基于服务端报价生成待支付订单；任何二维码、页面参数和客户端合计都不作为价格或履约凭据。

## 已确认事实

- 旧 `shoping` 在客户端计算商品原价、折扣价和合计，并把整份 `orderData` 编码进页面 URL。
- 旧购物车按桌号保存在本地 `orderDataList`，可能跨登录用户、营业日或商品版本残留。
- 旧 `shoping2` 在客户端分摊优惠券、金币、余额和现金金额，再把结果交给购买接口。
- 商品下架、库存变化、价格变化和桌码伪造缺少统一的服务端报价边界。

## 当前建议

- 只接受安全扫码模块验证后产生的短时 `OrderingContextRef`；路由不接受原始二维码、shopId、tableId 或桌名。
- 购物车本地草稿只保存 `productId + quantity + optionIds`，按账户、门店、桌位和营业场次隔离；不保存权威价格。
- 进入确认页前调用报价 port，服务端返回带版本与短时有效期的 `QuoteRef`、库存结果和金额明细。
- 报价变化必须展示差异并由用户重新确认；商品失效只移出受影响项，不静默替换。
- 创建订单提交 `QuoteRef + IdempotencyKey`；服务端重新校验桌位、库存、限购、优惠与最终金额。
- 点单范围仅包含门店商品；AA/VIP 套餐沿用各自订单入口，不混进桌边购物车。

## 页面与文档

- [KC-P-034 扫码点单商品/购物车页](pages/page_scan_ordering_cart/README.md) — `Approved for Development`
- [KC-P-035 点单确认页](pages/page_scan_order_confirmation/README.md) — `Approved for Development`
- [旧版审计](legacy_audit.md)
- [流程与状态](flow_and_state.md)
- [计价、库存与安全](pricing_inventory_security.md)
- [数据与 Fake 契约](data_and_api.md)
- [Mock 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 本期不包含

- 员工端改单、后厨出品、商品管理、配送、跨店购物车、赊账、拼单和多人实时共购。
- 客户端自行计算可支付金额，或真实超级接口、支付 SDK、扫码 SDK 接入。

## 已确认产品决策

1. 桌码必须先经安全扫码验证，原始二维码或手输桌号不能直接进入点单。
2. 购物车只保存商品选择，所有价格、优惠、库存和可售性由服务端报价确认。
3. 报价变更必须显式提示并重新确认，不能自动按新价格下单。
4. 本期一次订单只归属一个下单会员，不做多人实时拼单。
5. 下单成功进入支付处理页；暂不支持“先记账后统一结算”。

## 开发门禁

用户已于 2026-08-25 批准本版本；全部 48 页批准前不创建 Flutter UI，全局 `UI Flow Approved` 前不接真实商品、报价、下单、扫码或支付能力。
