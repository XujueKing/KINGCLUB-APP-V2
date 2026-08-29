# Design QA — 入场凭证页

- source truth：旧版 `pages/ticket/ticket.wxml`、`.wxss`，以及已批准的动态凭证文档
- implementation evidence：`audit/2026-08-29-device/01-ready.png` 至 `08-privacy-covered.png`
- viewport：Xiaomi 14 Pro，1080 × 2400 px
- state：V8 星光香槟套餐，Fake 动态凭证

## 可见结果

- 旧版深红紫径向背景、`POSITIONING CARD`、渐变票卡、粉色二维码区域和规则区得到保留。
- 可入场、已入场、离场确认、再次入场、离线和隐私状态共享同一票面框架，切换时页面层级稳定。
- 二维码维持高对比度和充足留白；场次、状态与安全说明不依赖二维码即可理解。
- 已入场状态保留旧版斜置印章，同时移除永久成员编号、客户端票价和同桌席位信息。

## 修正记录

- P1：已离场但未点击再次入场时提前显示二维码。
- 修复：`checkedOutReentryAllowed` 改为无码；用户明确点击后进入 `readyToEnter` 并签发全新 Fake token。
- 回归：真机截图 `05-checked-out-reentry.png` 与 `06-reentry-code.png`，专项测试 5/5 通过。

## 风险与限制

- 粉色正文在渐变票卡上的对比度需在生产前用自动化对比度工具复测，截图只能判断当前设备可读性。
- 当前只验证 Fake 生命周期遮盖；系统级录屏检测、临时亮度和截屏防护尚未接入。
- 缺少同状态旧版运行截图，无法认证 rpx/dp、字体栅格和间距的逐像素一致性。

final result: passed for approved UI/Fake scope; production security and exact legacy pixel fidelity remain gated

## 2026-08-29 订单绑定凭证 v3

- P1：A6 卡座订单的“查看凭证”打开了固定 V8 / 08月27日票面，造成订单与凭证不一致。
- 修复：订单详情只输出不透明 Fake `AdmissionRef`，凭证页恢复 A6 / 08月28日 / 星光香槟套餐投影。
- 旧版粉紫票卡、标题、动态码、倒计时和规则区布局均未改动。
- Android 1080 × 2400 真机可见 A6 完整票面，无溢出、遮挡或底部碰撞。

final result: passed for order-bound admission projection in UI/Fake scope
