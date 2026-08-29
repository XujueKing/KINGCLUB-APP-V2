# Design QA — 订单详情页

- source truth：旧版 `pages/shoping3`、`pages/detail-order` 与已批准的订单详情文档
- implementation evidence：`audit/2026-08-29-device/`
- viewport：Xiaomi 14 Pro，1080 × 2400 px
- state：扫码点单待支付、取消成功、VIP 组局已确认

## 可见结果

- 保留旧版黑色画布、香槟金标题、浅棕金订单/商品/金额卡片和紧凑分隔线。
- 状态、订单摘要、商品、金额、进度和底部动作保持一条清晰纵向核对路径。
- 已确认订单只提供查看凭证，待支付订单提供取消和继续支付，取消订单只保留安全刷新和客服动作。
- 正常路径不再显示 `Fake`、`Mock`、内部引用或测试说明。

## 本轮修正

- P1：金额卡、取消弹窗和取消结果横幅直接显示 Fake/测试说明。
- 修复：金额卡删除测试说明，取消确认、成功提示和客服降级全部改为正式产品文案。
- P1：取消扫码点单后错误替换为另一条 C3 VIP 示例订单。
- 修复：取消只更新当前扫码订单的状态和时间线，保留原标题、桌位、商品、金额与引用。
- P2：取消弹窗的次要操作偏右，与全局确认弹窗节奏不一致。
- 修复：“暂不取消”和主按钮在弹窗动作区居中对齐。

## 风险与限制

- 当前详情、动作结果和引用均为本地 Fake；真实订单、支付、退款与 WebSocket 继续受全局门禁阻断。
- 支付处理页属于 KC-P-038，本轮只确认从详情页安全跳转，支付页自身正式文案在下一轮验收。
- 旧版不存在统一消费者订单详情的同状态运行截图，本轮不声明逐像素一致。
- 200% 字体、横屏和完整屏幕阅读器顺序留到全局无障碍验收轮次。

final result: passed for approved UI/Fake scope after fixing two P1 issues; production authority and exact legacy pixel fidelity remain gated

## 2026-08-29 v3 支付后详情验收

- audit evidence：`audit/2026-08-29-post-payment-audit/02-order-detail.png`
- post-fix evidence：`audit/2026-08-29-paid-scan-v3/03-paid-top-final.png`、`02-paid-lower.png`
- 审计发现 P1：支付成功后的“查看订单”错误落到旧的 V8/1156 待支付样例，且门店显示为建宁店。
- 修复后统一为湖南工大店、888号桌、轩尼诗 XO、芝华士12年、3710/-30/3680，并显示“已支付 / 支付已确认”。
- 已支付扫码点单不再显示继续支付或入场凭证；底部只保留客服与刷新状态。
- 订单详情与支付专项测试 23/23 通过，相关 Dart 静态检查无问题。

final result: passed

## 2026-08-29 v5 AA 支付后详情验收

- source visual truth：用户于 2026-08-29 提供的旧版黑金订单详情参考与已批准的订单详情契约
- implementation evidence：`../../../../club/feature_aa_reservation/qa/2026-08-29/aa-order-detail.png`
- viewport：Android 真机 `1080 × 2400 px`
- state：V5 AA 预订、无抵扣、支付已确认
- 订单详情正确展示 `KING CLUB AA预订 / V5 / 3880卡座套餐 / 本人1席 / ¥268`，没有 888 桌、扫码酒品、继续支付或取消订单。
- 3880 套餐使用已批准的真实海报素材；浅棕金信息卡、黑色进度卡和底部动作区沿用现有旧版派生体系。
- 物理返回键直接回到 V5 套餐详情，不回到支付结果页。
- 专项测试 41 项通过，`flutter analyze` 无问题。

final result: passed
