# AA 确认订单页交互

| 触发 | 行为 |
|---|---|
| 选择优惠券/余额/金币方案 | 调用 `requote`，服务端返回完整新报价 |
| 查看规则 | 打开当前 terms snapshot，只读展示 |
| 勾选同意 | 仅对当前 quoteRevision + termsSnapshotRef 生效 |
| 确认并去支付 | 复用本页面稳定幂等键调用 `createReservation` |
| 返回 | 未提交直接回详情；提交中先对账，不能盲目取消 |
| 提交超时 | `reconcileSubmission(idempotencyKey)`，不生成新键 |
| 返回 pendingPayment | `openPayment(PaymentIntentRef)`；未开放时使用 AA-M16 |
| 返回 confirmed | `openOrderDetail(OrderRef)` |

- 按钮启用条件：报价有效、无重报价、规则已同意、允许提交且在线。
- 重复点击、App 前后台切换和网络重试均保持同一幂等键，直到得到确定结果或明确无订单。
- 服务端返回价格/规则版本变化时清除同意勾选，并将差异置于可见区域。
- 页面和日志禁止保存完整优惠券编号、支付凭据、实名、性别或客户端计算金额。
- 倒计时为读屏播报提供低频关键提醒，禁止每秒抢占播报焦点。
