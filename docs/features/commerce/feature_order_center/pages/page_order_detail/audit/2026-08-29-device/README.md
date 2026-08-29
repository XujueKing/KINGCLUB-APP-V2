# KC-P-037 Android 真机验收

- 日期：2026-08-29
- 设备：Xiaomi 14 Pro（`23116PN5BC`，arm64-v8a）
- 分辨率：1080 × 2400
- 构建：Flutter preview debug，Fake/Mock 数据
- 入口：订单中心 → `OrderDetailRoute`

## 验收路径

1. 打开待支付扫码订单，核对状态、订单信息、商品、金额、进度和底部动作。
2. 进入取消确认，核对正式文案、动作对齐和防误触说明。
3. 确认取消，验证仍保留原订单标题、商品、桌位、金额和引用。
4. 打开已确认 VIP 订单，确认只有查看凭证主动作。
5. 分别验证入场凭证与支付处理安全跳转。
6. 打开隐藏场景切换器，配合自动化验证离线、未知、无效引用、会话失效、冲突和结果未知。

## 证据

- [修正前默认态](01-before.png)
- [修正后默认态](02-default.png)
- [修正前取消弹窗](03-cancel-dialog.png)
- [修正前错误换单](04-cancelled.png)
- [最终取消弹窗](05-cancel-dialog-final.png)
- [最终取消结果](06-cancelled-final.png)
- [已确认订单](07-confirmed.png)
- [入场凭证交接](08-admission-handoff.png)
- [支付处理交接](09-payment-handoff.png)
- [隐藏场景切换器](10-scenarios.png)

## 发现与修复

- 移除金额卡、取消弹窗和结果横幅里的 Fake/测试说明，正常用户路径恢复正式文案。
- 修复取消扫码点单后错误切换为 C3 VIP 示例订单；现在只更新当前订单状态与时间线。
- 将取消弹窗次要操作居中，与主按钮保持一致轴线。
- 订单详情专项 Widget 测试 10/10 通过，`flutter analyze` 无问题。

结果：KC-P-037 在 UI/Fake 范围内通过 Android 真机验收；真实订单、支付、退款和 WebSocket 接入继续保持阻断。
