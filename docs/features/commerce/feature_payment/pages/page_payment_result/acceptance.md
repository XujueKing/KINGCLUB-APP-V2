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

## 2026-08-29 v3 正式点单支付交接

- [x] 点单提交后替换进入支付页，返回不能再次提交原报价
- [x] 默认门店、桌号、商品和 `¥3680.00` 与上一步一致
- [x] AA PaymentIntentRef 映射为 V5/3880 套餐/冻结应付金额，且不影响点单 888 桌夹具
- [x] 正常准备、处理中和结果状态不显示任何 Fake/Mock/内部引用/测试说明
- [x] 支付成功只在服务器确认状态显示
- [x] Android 真机完成准备态与成功态验收
- [x] AA 成功态“查看订单”进入同金额的 V5/3880 AA 详情，返回不重复进入支付页
- [x] 支付专项测试、路由回归和静态检查通过

## 2026-08-29 横屏恢复验收

- [x] `2400×1080` 横屏成功态不再出现 RenderFlex overflow
- [x] 成功文案、“查看订单”和城市落款可滚动到达
- [x] `1080×2400` 竖屏旧版居中排版无回归
- [x] Widget 横屏回归、支付专项测试与 `flutter analyze` 通过

证据：[J03 横屏修复截图](../../../../foundation/feature_mock_runtime/audit/2026-08-29-j03/08-payment-landscape-fixed.png)。

## 2026-08-29 支付安全提示条复验

- [x] 盾牌图标与提示文字左侧关系稳定且上下居中
- [x] 正常 Android 宽度无视觉下沉、上浮或基线错位
- [ ] 窄屏/大字体换行时不溢出且整组保持垂直居中
