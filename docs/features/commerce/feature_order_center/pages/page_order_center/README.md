# 订单中心页

- Scope ID：`KC-P-036`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[消费者订单中心](../../README.md)
- 旧版来源：旧订单入口整合
- 路由：`OrderCenterRoute`，`/commerce/orders`
- 设计版本：`Legacy Orders Consolidation v2 / List`
- 最后更新：2026-08-27

## 用户任务与线框

```text
[返回]              我的订单
[全部] [待支付] [进行中] [已完成/售后]
[类型标签] 标题                         [状态]
场次/桌位摘要
¥268 · 8月25日 20:30             [查看详情]
...
```

状态以文字+颜色双编码；列表卡不承载取消等高风险写操作。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。

## 旧版复刻基线

**已确认事实**

- 旧版没有统一的“我的订单”列表，订单分散在 `order`、`order-manage`、`shoping3`和 `detail-order`。
- V2 列表视觉取旧版 `mybalance` 的黑色画布、顶部横向分类、金色选中线、密集列表和弱分隔线；订单内容取 `shoping3` 的棕金商品信息层级。
- AA、VIP 和扫码点单使用同一列表，通过类型标签和摘要区分；局长管理不进入本页。

**UI Mock 安全边界**

- 列表只传递不透明 Fake `OrderRef`，不传 `userAccount`、整份订单 JSON或金额参数。
- 列表不放置取消、支付、退款或核销写操作；仅允许进入详情。
- 无 WebSocket 直改状态；Fake 事件只显示“有更新”并要求刷新。
