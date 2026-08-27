# 订单详情页验收

- [x] 状态、业务摘要、明细、金额、时间线和动作层级明确
- [x] OrderRef 无效、越权、离线、未知状态和会话失效明确
- [x] allowedActions、取消二次确认和结果未知对账明确
- [x] 支付与入场出口只传受控引用
- [x] 隐私和无障碍边界明确
- [x] 用户于 2026-08-25 批准 `Order Center Wireframe v1 / Detail`

UI Mock 阶段验证 ORDERS-M07～M18；全局文档门禁已满足，可以实现页面 Fake 流程。

## Legacy UI Mock 准入补充

- [x] 旧版视觉来源冻结为 `shoping3` 商品/金额卡片和 `detail-order` 纵向详情结构
- [x] 不复制旧版通过 URL 传递的订单 JSON、账号、金额或桌位参数
- [x] 默认态、已确认、退款中、离线、未知、无效引用、会话失效和取消异常均有 Fake 场景
- [x] 支付、凭证、支持和取消出口只传递受控引用或本地 Fake 意图
- [x] 页面不调用真实超级接口、WebSocket、支付 SDK 或生产存储

## 2026-08-27 Android UI Mock 验收记录

- [x] 订单中心四类 Fake 订单均可使用不透明 `OrderRef` 打开对应详情投影
- [x] 待支付详情完整展示状态、门店/桌位、商品、金额、时间线和 `allowedActions`
- [x] 已确认详情只提供客服与查看凭证，退款/完成/取消详情不误放支付动作
- [x] 取消二次确认、成功、状态冲突和结果未知对账均为本地 Fake 流程
- [x] 离线与未知状态保留只读详情并移除写动作
- [x] 无效/越权/不存在引用使用同一安全错误，会话失效清空业务内容
- [x] Android `1080 × 2400` 默认态、滚动态、已确认态和场景选择器无溢出或底部碰撞
- [x] 实机发现的全局按钮无限宽约束已用详情动作按钮显式尺寸修复
- [x] `flutter analyze` 无问题
- [x] 详情页 9 项专项测试、完整 Flutter 96 项测试全部通过

实机截图：

- `screenshots/android_order_detail_v2.png`
- `screenshots/android_order_detail_scrolled_v2.png`
- `screenshots/android_order_detail_confirmed_v2.png`
- `screenshots/android_order_detail_scenarios_v2.png`

旧版没有与当前统一消费者详情同状态的运行截图，因此像素级复刻检查仍受阻；本轮已完成源码结构、Android 实机布局和 Fake 流程验收。
