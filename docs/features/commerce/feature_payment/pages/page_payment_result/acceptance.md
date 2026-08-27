# 支付处理与结果页验收

- [x] 权威金额、支付方式、处理中和结果层级明确
- [x] 成功、取消、失败、pending、unknown、过期状态明确
- [x] provider 回调后服务端确认与恢复规则明确
- [x] 防重复 attempt、冷启动和返回路径明确
- [x] 隐私、无障碍和敏感日志边界明确
- [x] 用户于 2026-08-25 批准 `Payment Wireframe v1`

UI Mock 阶段验证 PAY-M01～M20；全局文档门禁已满足，可以实现页面 Fake 流程。

## Legacy UI Mock 准入补充

- [x] 旧版视觉来源冻结为 `pay`/`success` 的居中结果结构和原始成功、微信支付素材
- [x] 准备态只显示 Fake 权威金额和服务端可用支付方式，不允许输入资产分摊
- [x] provider success、cancel、fail、无回调和晚到回调均先经过 Fake reconcile
- [x] 处理中、成功、取消、失败、结果未知、过期、订单变化、离线和会话失效均有 Fake 状态
- [x] 所有路由和动作只传递不透明引用，不传递金额、用户、provider 参数或成功标记
- [x] 页面不调用真实超级接口、支付 SDK、WebSocket 或生产存储

## 2026-08-27 Android UI Mock 验收记录

- [x] 准备态展示 Fake 服务端权威金额、微信支付可用态和余额支付禁用态
- [x] 连续点击主按钮只创建一个 `FakePaymentAttemptRef`，处理中禁止重复 attempt
- [x] provider success 不直接进入成功页，只有 Fake 服务端确认 `SUCCEEDED` 后展示支付成功
- [x] provider cancel、provider fail、无回调、确认 pending 和晚到成功均保留原 attempt 并进入对应恢复路径
- [x] 过期 intent、订单状态变化、离线、支付方式不可用和会话失效均有阻断或恢复界面
- [x] `¥0.00` 订单走 Fake 零金额确认，不创建支付 attempt，也不打开 provider
- [x] 返回订单、继续查询、安全重试和重置登录路径均可从当前状态到达
- [x] Android `1080 × 2400` 准备、核验、成功、待确认和专项场景截图无溢出或底部操作冲突
- [x] `flutter analyze` 无问题
- [x] 支付专项 12 项测试通过；Flutter 全量 108 项测试通过

本记录只批准 UI 与 Fake 流程，不批准接入真实超级接口、支付 SDK、WebSocket 或生产数据。
