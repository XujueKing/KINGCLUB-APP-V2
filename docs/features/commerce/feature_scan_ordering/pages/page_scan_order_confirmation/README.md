# 点单确认页

- Scope ID：`KC-P-035`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[扫码点单](../../README.md)
- 旧版来源：`shoping2`
- 路由：`ScanOrderConfirmationRoute`，`/commerce/ordering/confirm`，`$extra: QuoteRef`
- 设计版本：`Legacy Shoping2 Replica v2 / Confirmation`
- 最后更新：2026-08-27

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

## 旧版复刻基线

**已确认事实**

- 页面以旧版 `pages/shoping2` 的黑棕径向背景、居中金色标题、棕金圆角信息卡、商品明细和固定底部金额/主操作区为视觉主体。
- 商品行保留图片、商品名、规格、单价、数量与小计，支持展开/收起更多商品。
- App 不复制小程序宿主胶囊。

**已批准的安全差异**

- 删除旧版在确认页中手填金币、余额、优惠券与现金分摊的控件；仅显示 Fake 服务端报价结果。
- 旧版“立即支付”改为“提交订单”；成功只能表示创建待支付订单，不得表示支付成功。
- 支付方式改为只读说明“订单创建后选择”，后续由权威 `PaymentIntent` 决定。
- 路由只携带不透明 Fake `QuoteRef`，不携带金额、账号、原始二维码或订单 JSON。
