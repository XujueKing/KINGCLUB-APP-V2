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

## 2026-09-09 审计修复补充

按[本轮对照与验收条件](../../../audits/2026-09-09-miniprogram-alignment.md)实现：Fake 支付意图必须解析到已登记的同一订单；缺失/未知引用失败关闭。支付成功更新该订单，不生成另一个“已支付订单号”；取消支付保留待支付订单。重进已支付订单不提供再次支付，清理后的旧异步结果不可恢复数据。
