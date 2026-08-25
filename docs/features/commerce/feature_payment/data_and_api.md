# 支付数据与 Fake 契约

## 引用与展示模型

- `PaymentIntentRef { opaqueId, expiresAt }`
- `PaymentAttemptRef { opaqueId }`
- `PaymentIntentView`：订单摘要、权威应付金额、支付方式、到期时间、allowedActions
- `PaymentStatusView`：processing/succeeded/failed/cancelled/pending、更新时间、可恢复动作

## UI 阶段 ports

- `PaymentPort.loadIntent(intentRef)`
- `PaymentPort.createAttempt(intentRef, methodId, idempotencyKey)`
- `PaymentProviderPort.handoff(attemptRef)`
- `PaymentPort.reconcile(attemptRef)`
- `PaymentPort.cancelAttempt(attemptRef)`（仅在服务端允许时）

UI/Mock 阶段 Fake provider 必须模拟 success、cancel、fail、无回调和晚到回调。真实 SDK adapter 在项目 `UI Flow Approved` 后单独评审。
