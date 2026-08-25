# 订单详情页

- Scope ID：`KC-P-037`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[消费者订单中心](../../README.md)
- 旧版来源：`shoping3`、`detail-order`
- 路由：`OrderDetailRoute`，`/commerce/orders/detail`，`$extra: OrderRef`
- 设计版本：`Order Center Wireframe v1 / Detail`
- 最后更新：2026-08-25

## 用户任务与线框

```text
[返回]              订单详情
[状态：待支付/已确认/...]
订单类型 · 场次/桌位摘要
[商品/套餐明细]
商品小计 / 优惠 / 实付 / 退款
[状态时间线]
[联系客服]                [继续支付/查看凭证]
```

主操作区只渲染 allowedActions；订单号默认部分隐藏，支持受控复制时单独评审。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
