# 订单中心页

- Scope ID：`KC-P-036`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[消费者订单中心](../../README.md)
- 旧版来源：旧订单入口整合
- 路由：`OrderCenterRoute`，`/commerce/orders`
- 设计版本：`Order Center Wireframe v1 / List`
- 最后更新：2026-08-25

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
