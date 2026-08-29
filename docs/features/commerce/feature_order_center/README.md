# 消费者订单中心

- Scope ID：`KC-F-028`
- 文档状态：`UI Mock Implemented / Android Device Verified`
- 所属业务域：`commerce`
- M0 范围：`In Release Scope`
- 设计版本：`Order Center v1`
- 最后更新：2026-08-29

## 目标与用户价值

在一个消费者入口查询本人 AA、VIP 组局和扫码点单订单，理解当前权威状态、可执行动作和后续去向。

## 已确认事实

- 旧订单入口分散在 `order`、`order-manage`、`shoping3`、`detail-order` 等页面，消费者与局长/管理动作混杂。
- 旧页面通过 URL 传递整份订单或账号，客户端字段可能陈旧、被修改或越权。
- 订单状态编号和金额口径因类型不同而分散，支付、取消、入场等动作缺少统一 allowedActions。

## 当前建议

- 订单中心只查询当前会话所属用户，路由和请求不接受 userAccount。
- 统一展示状态族：`awaitingPayment`、`confirmed`、`inService`、`completed`、`cancelled`、`refunding`、`refunded`、`disputed`；服务端映射各业务内部状态。
- 详情只接收不透明 `OrderRef`，所有金额、状态、商品和参与信息重新读取。
- 页面动作完全来自服务端 `allowedActions`；客户端不根据订单类型/时间自行解锁支付、取消、入场或申诉。
- 本期订单中心只做消费者查询与安全跳转；局长组局管理留在 KC-P-032，员工/代理后台不纳入。

## 页面与文档

- [KC-P-036 订单中心页](pages/page_order_center/README.md) — `UI Mock Implemented / Android Device Verified`
- [KC-P-037 订单详情页](pages/page_order_detail/README.md) — `UI Mock Implemented / Android Device Verified`
- [旧版审计](legacy_audit.md)
- [状态与动作模型](state_machine.md)
- [数据与 Fake 契约](data_and_api.md)
- [Mock 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 本期不包含

- 管理端履约、局长成员管理、退款审批、客服工单处理、发票、物流和删除订单。
- 真实超级接口、WebSocket 或支付/推送接入。

## 已确认产品决策

1. AA、VIP 和扫码点单统一进入一个消费者订单中心，以类型标签区分。
2. 默认不允许删除历史订单，只允许按状态筛选。
3. 取消、继续支付、查看入场凭证等按钮完全使用服务端 allowedActions。
4. 订单详情展示服务端权威金额和状态历史，不展示其他成员敏感资料。
5. 退款与申诉本期只展示状态和“联系客服”出口，不在 App 内建设完整申请流程。

## 开发门禁

用户已于 2026-08-25 批准本版本；全部 48 页批准前不创建 Flutter UI，全局 `UI Flow Approved` 前不接真实订单与支付能力。
