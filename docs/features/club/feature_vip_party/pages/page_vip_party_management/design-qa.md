# Design QA — 局长组局管理页

- source truth：旧版 `pages/order-manage/order-manage.wxml`、`.wxss`，以及已批准的消费者局长管理文档
- implementation evidence：`audit/2026-08-29-device/01-overview.png`、`02-bill.png`、`03-members.png`、`04-invite-sheet.png`
- viewport：Xiaomi 14 Pro，1080 × 2400 px
- state：V8 卡座，公开招募，消费者局长角色

## 可见结果

- 旧版居中卡座标题、返回按钮和“概况 / 账单 / 成员”三栏结构保留，选中项使用金色下划线。
- 黑棕背景、低对比分隔线、灰白文字及粉色/金色主动作保持旧版视觉语言。
- 概况、账单和成员页在真机上无溢出、裁切、底部导航碰撞或不可读文本。
- 已付款成员只读；未付款占位、未接受邀请和空位分别显示正确的局长动作。
- 员工订单状态、服务员分配、商品确认、付费踢人和客户端固定赔付均未进入消费者页面。

## 限制

- 没有可用于同状态并排比较的旧版运行截图，无法认证 rpx/dp、字体栅格和间距的逐像素一致性。
- 当前结论仅覆盖 UI/Fake；真实数据权威、版本冲突和事件重读仍等待项目级真实接入门禁。

final result: passed for approved UI/Fake scope; exact legacy pixel fidelity remains unclaimed
