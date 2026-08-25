# 支付处理与结果

- Scope ID：`KC-F-029`
- 文档状态：`Approved for Development`
- 所属业务域：`commerce`
- M0 范围：`In Release Scope`
- 设计版本：`Payment Orchestration v1`
- 最后更新：2026-08-25

## 目标与用户价值

以一个可恢复的流程完成支付方式选择、外部支付交接、服务端确认和结果展示，避免把 SDK 回调或页面参数当成支付成功凭据。

## 已确认事实

- 旧 `pay` 从 URL 解析完整 `orderData`，按 mode 分支调用多个购买/支付接口。
- 旧页面和 `shoping2/order2` 在客户端计算余额、金币、现金及优惠分摊。
- 旧支付 SDK 返回 `requestPayment:ok` 后可直接显示成功；`mode=8` 甚至可只凭路由参数进入成功展示。
- 取消、失败、未知和服务端已成功但客户端未收到结果的恢复规则不统一。

## 当前建议

- 页面只接收短时不透明 `PaymentIntentRef`；订单、用户、金额和 provider 参数不进入路由。
- 服务端返回应付金额、可用支付方式、支付意图版本与 allowedActions；客户端不能修改支付金额或资产分摊。
- 用户选择支付方式后创建 `PaymentAttemptRef`，再由未来 adapter 调用具体 SDK。
- SDK 的 success/cancel/fail 都只触发服务端查询；仅 `paymentStatus=SUCCEEDED` 才显示支付成功。
- App 被杀、切后台、网络中断或回跳丢失时，用 PaymentAttemptRef/OrderRef 恢复查询，不再次扣款。
- 支付处理中保留明确“正在确认”，超过策略时间转“结果待确认”，可去订单详情继续查询。

## 页面与文档

- [KC-P-038 支付处理与结果页](pages/page_payment_result/README.md) — `Approved for Development`
- [旧版审计](legacy_audit.md)
- [支付状态机](state_machine.md)
- [支付安全与恢复](security_and_recovery.md)
- [数据与 Fake 契约](data_and_api.md)
- [Mock 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 本期不包含

- 退款发起/审批、充值、提现、绑卡、账单对账 UI、员工收款、分账和支付密码设置。
- 真实微信/支付宝/Apple Pay 等 SDK，正式商户号、回调和生产超级接口。

## 已确认产品决策

1. 支付页不接受客户端金额，只显示服务端 PaymentIntent 的权威金额。
2. SDK 返回成功不等于支付成功，必须查询服务端确认。
3. 支付取消保留待支付订单，不自动取消业务订单。
4. 结果未知不重复发起扣款，先持续查询，用户可安全返回订单详情。
5. 余额/金币/优惠如何抵扣由后续资产契约和服务端决定，本页不允许手填分摊金额。

## 开发门禁

用户已于 2026-08-25 批准本版本；全部 48 页批准前不创建 Flutter UI，全局 `UI Flow Approved` 前不得接真实支付、订单、资产或回调能力。
