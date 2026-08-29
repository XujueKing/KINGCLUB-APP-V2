# Design QA — 订单中心页

- source truth：旧版 `pages/mybalance`、`pages/shoping3` 与已批准的统一消费者订单中心文档
- implementation evidence：`audit/2026-08-29-device/`
- viewport：Xiaomi 14 Pro，1080 × 2400 px
- state：AA、VIP 组局、扫码点单和售后订单本地混合列表

## 可见结果

- 延续旧版 `mybalance` 的黑色画布、横向分类、金色选中线、密集列表和弱分隔节奏。
- 订单卡使用旧版 `shoping3` 的棕金信息层级，类型、标题、状态、摘要、时间、金额和详情入口均可快速扫读。
- 四类筛选保持同一位置；待支付筛选不会残留其他状态订单，分页追加后无重复卡片。
- 空态和失败态保持正式产品文案，正常路径不出现 `Fake`、`Mock` 或内部引用。

## 交互结果

- 订单卡只打开详情并传递不透明 `OrderRef`，列表没有取消、支付、退款或核销写操作。
- 分页可追加第二页并显示到底提示；首屏失败可恢复；全部为空提供返回首页入口。
- Fake 场景切换器仅通过长按标题进入，不干扰正式视觉。

## 风险与限制

- 旧版不存在同状态的统一订单中心页面，本轮验证的是已批准的旧版结构组合，不声明逐像素一致。
- 当前订单、状态事件、刷新和分页均为本地 Fake；真实超级接口、WebSocket 和支付能力仍受全局门禁阻断。
- 200% 系统字体、横屏和完整屏幕阅读器顺序留到全局无障碍验收轮次复测。

final result: passed for approved UI/Fake scope; production order authority and exact legacy pixel fidelity remain gated

## 2026-08-29 支付后一致性 v3

- 支付后返回列表，首条已是 `KINGBAR 湖南工大店`、888 号桌、轩尼诗 XO 与芝华士 12 年，实付金额为 ¥3680。
- 状态为“进行中”并归入进行中筛选；原 V8 待支付样本保留用于状态族验收。
- 真机点击首条后打开同一笔“已支付”订单详情，商店、桌号、商品和金额一致。
- 1080 × 2400 下列表无溢出或底部遮挡；证据见 `audit/2026-08-29-paid-order-audit/`。

final result: passed for paid-order list/detail continuity in UI/Fake scope

## 2026-08-29 AA 支付后列表一致性 v4

- V5/3880 AA 已确认订单按创建时间位于“全部”首屏首位，标题、摘要、海报、时间和 ¥268 与确认、支付和详情页一致。
- “进行中”筛选只保留 V5 AA、888 桌出品中订单和 A6 已确认订单；待支付与完成售后样例没有混入。
- 点击首条卡片只传 `order-aa-v5-paid-r0-0829`，打开同一 AA 详情；物理返回后仍保留“进行中”筛选。
- 1080 × 2400 真机下没有标题截断、金额碰撞、卡片溢出或底部遮挡。
- 证据：`audit/2026-08-29-aa-paid-v4/01-all-aa-first.png` 至 `04-back-keeps-active.png`。
- 订单中心、详情和 AA 专项测试 42 项通过；`flutter analyze` 无问题。

final result: passed
