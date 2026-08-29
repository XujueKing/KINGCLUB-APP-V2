# KC-P-032 Android 真机验收

- 日期：2026-08-29
- 设备：Xiaomi 14 Pro（`23116PN5BC`，arm64-v8a）
- 构建：Flutter preview debug，Fake/Mock 数据
- 入口：VIP 组局列表展开 V8 局长卡片 → `管理组局`

## 验收路径

1. 概况、账单、成员三栏切换。
2. 选择一位 KingClub 好友并二次确认发送邀请。
3. 二次确认撤销刚发送的邀请。
4. 二次确认释放未付款占位；已付款成员保留。
5. 二次确认关闭公开招募并验证状态更新。
6. Android 系统返回回到 VIP 组局页。

## 证据

- [01-overview.png](01-overview.png)
- [02-bill.png](02-bill.png)
- [03-members.png](03-members.png)
- [04-invite-sheet.png](04-invite-sheet.png)

结果：主流程和返回路径通过；未发现布局溢出、遮挡、不可点击或状态未更新问题。

说明：旧版 `order-manage` 只有 WXML/WXSS 源码，没有同状态运行截图，因此本轮确认结构、视觉语言和交互范围，不声明逐像素一致。
