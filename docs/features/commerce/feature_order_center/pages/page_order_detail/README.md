# 订单详情页

- Scope ID：`KC-P-037`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[消费者订单中心](../../README.md)
- 旧版来源：`shoping3`、`detail-order`
- 路由：`OrderDetailRoute`，`/commerce/orders/detail`，`$extra: OrderRef`
- 设计版本：`Legacy Order Detail v2 / Fake Flow`
- 最后更新：2026-08-27

## 旧版视觉基线

- 顶部延续消费者订单中心的黑色画布、香槟金标题和返回键，不复刻微信胶囊。
- 订单信息、商品明细和金额汇总复刻 `shoping3` 的浅棕金卡片、深棕文字、紧凑分隔线与商品图文层级。
- 状态摘要与时间线吸收 `detail-order` 的纵向信息结构，但不展示旧版交易对手头像、完整账号或可枚举订单号。
- 底部动作区使用黑色渐变托底；只展示当前 Fake `allowedActions`，不会从状态名称自行推导动作。

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

## 本轮 UI Mock 范围

- 默认演示“扫码点单 · 待支付”，包含订单摘要、两件商品、金额拆分和状态时间线。
- 通过标题长按切换已确认、退款中、离线缓存、未知状态、无效引用、会话失效、取消冲突和取消结果未知。
- “继续支付”只生成 Fake `PaymentIntentRef`；“查看凭证”只生成 Fake `AdmissionRef`；不会调用支付 SDK、超级接口或 WebSocket。
- 取消必须二次确认；提交冲突后重读 Fake 最新状态，结果未知时保留同一 Fake 幂等键并允许对账。
- 页面返回订单中心时只传递 `OrderRef`，不通过 URL 或路由复制订单、金额、账号和桌位对象。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
