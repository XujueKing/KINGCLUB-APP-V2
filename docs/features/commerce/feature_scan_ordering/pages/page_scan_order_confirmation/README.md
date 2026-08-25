# 点单确认页

- Scope ID：`KC-P-035`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[扫码点单](../../README.md)
- 旧版来源：`shoping2`
- 路由：`ScanOrderConfirmationRoute`，`/commerce/ordering/confirm`，`$extra: QuoteRef`
- 设计版本：`Scan Ordering Wireframe v1 / Confirmation`
- 最后更新：2026-08-25

## 用户任务与线框

核对服务端报价、桌位和商品，明确提交后创建待支付订单。

```text
[返回]              确认点单
门店名 · A08桌 · 报价剩余 04:32
[商品明细]
商品小计                         ¥300
优惠                            -¥32
应付金额                         ¥268
[价格或库存变化提示区]
[返回修改]                    [提交订单]
```

- 不在本页让用户手填余额、金币或现金分摊；支付方式由支付流程基于权威 PaymentIntent 决定。
- 主按钮提交时明确“提交订单”，不能提前写“支付成功”。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
