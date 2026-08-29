# KC-P-035 Android 真机验收

- 日期：2026-08-29
- 设备：Xiaomi 14 Pro（`23116PN5BC`，arm64-v8a）
- 分辨率：1080 × 2400
- 构建：Flutter preview debug，Fake/Mock 数据
- 入口：`ScanOrderConfirmationRoute` / `/commerce/ordering/confirm`

## 验收路径

1. 核对默认报价、门店、桌位、商品、优惠与应付金额。
2. 提交订单，确认只生成待支付结果并进入本人订单中心。
3. 切换价格变化，确认显式勾选前不能提交，勾选后恢复提交。
4. 切换报价过期，确认倒计时归零、提交禁用和刷新恢复。
5. 切换提交结果未知，确认只能查询原提交且不允许重复创建。

## 证据

- [02-ready.png](02-ready.png)
- [03-order-created.png](03-order-created.png)
- [04-order-center-handoff.png](04-order-center-handoff.png)
- [05-price-change.png](05-price-change.png)
- [06-price-accepted.png](06-price-accepted.png)
- [07-quote-expired.png](07-quote-expired.png)
- [08-refreshed.png](08-refreshed.png)
- [09-result-reconcile.png](09-result-reconcile.png)
- [10-reconciled-order-created.png](10-reconciled-order-created.png)

## 发现与修复

- 初始真机验收发现底部直接显示 “Fake Quote”，提交兜底结果还会显示内部假订单编号和测试说明。
- 已改为正式的金额确认、待支付订单和订单中心引导文案；正常用户路径不再显示 `Fake`、`Mock`、`QuoteRef` 或内部订单引用。
- 报价变化、过期刷新和结果未知对账均通过真机交互复核；专项测试 6/6 通过。

结果：旧版 `shoping2` 视觉主体、报价确认、安全差异和提交防重路径通过 Android 真机验收。

说明：旧版只有 WXML/WXSS 源码，没有同状态运行截图，因此本轮确认结构、视觉语言和交互范围，不声明逐像素一致。
