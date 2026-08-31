# 一起玩 AA 预订页

- Scope ID：`KC-P-027`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[一起玩 AA 预订](../../README.md)
- 旧版来源：`Choose`
- 路由：`AaReservationsRoute`，`/club/aa`
- 设计版本：`AA Reservation Legacy Replica v2 / Landing`
- 最后更新：2026-08-31

## 用户任务与旧版版式

选择营业日，查看已有 AA 预订和可订套餐，并安全进入套餐详情。

```text
[旧版返回箭头]        一起玩AA预定
[今天 08.26] [周四 08.27] [周五 08.28] ...

[未预订卡：失败图标 + 当日未预订] [随机预订]
[旧版完整规则文案]

[卡座图形/模糊余量] [套餐名/规则摘要] [价格/加入]
[卡座图形/模糊余量] [套餐名/规则摘要] [价格/加入]
[售罄灰态]

[一人一席与营业时间说明]
```

- 背景、金色日期选中态、圆角、卡片高度、按钮胶囊形态和纵向节奏按旧版 `Choose.wxss` 复刻。
- App 不显示微信小程序右上角胶囊，也不在标题栏放 `UI MOCK` 字样。
- “随机预订”在 Fake 阶段选择第一个可用套餐并进入详情，不跳过详情或确认页，也不表示已选定卡座。

- 日期使用服务端 `ServiceDay`，不在 UI 硬编码 14 天或营业时段。
- 已有有效预订优先展示；同一营业日有待支付/已确认预订时禁用新订入口。已确认但未到营业日前一天时只显示“卡座待揭晓”；进入揭晓窗口后才使用旧版紫色定位卡展示具体卡座号、席位矩阵和二维码入口。
- 套餐卡只显示匿名容量、价格、规则摘要和模糊余量，不展示同桌人员信息。
- 空态区分未开售、已截止、无场次、全部售罄和功能维护。
- 200% 字体下日期条可横向滚动，卡片纵向扩展；价格和状态具备读屏标签。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。

## Android UI/Fake 实现证据

- 2026-08-27 已在 `Medium_Phone / 1080×2400` 实机模拟器验证旧版入口层级、日期切换、随机选择、套餐进入和售罄灰态。
- 截图：[android_aa_legacy_replica_v2.png](android_aa_legacy_replica_v2.png)
- 已有待支付：[android_aa_pending_payment.png](android_aa_pending_payment.png)
- 已有确认：[android_aa_confirmed.png](android_aa_confirmed.png)
- 当日售罄：[android_aa_sold_out.png](android_aa_sold_out.png)
- 离线快照：[android_aa_offline.png](android_aa_offline.png)
- 无可推荐套餐：[android_aa_no_recommendation.png](android_aa_no_recommendation.png)
- 当前仍缺旧版运行时同状态截图，因此像素级对照结论保持 `blocked`；本次以 `Choose.wxml/.wxss` 与现有旧版入口截图为源码级视觉依据。
- 本轮验收截图：[2026-08-28 列表主状态](../../qa/2026-08-28/01-list.png)；主入口、日期条、推荐入口、套餐卡与售罄灰态均在当前构建重新验证。

## 异常与已有预订 Fake 状态补充

- 不增加常驻测试按钮，长按页面标题打开仅供本地验收的状态选择面板，保持旧版页面外观不变。
- `readyWithPendingPayment`：顶部改为旧版黑金待支付卡，显示套餐、占位倒计时和“继续支付”；同日所有套餐禁用。
- `readyWithConfirmedPendingReveal`：顶部显示黑金“预订已确认 / 卡座待揭晓”卡，说明营业日前一天揭晓，不显示号码或二维码。
- `readyWithAssignmentRevealed`：顶部使用旧版紫色定位卡；整卡可点击进入 `POSITIONING CARD` 二维码页，同日所有新订入口禁用。
- `soldOut`：顶部显示当日已售罄，套餐卡保留信息但按钮统一为“售罄”。
- `offlineCached`：顶部显示“离线快照”，套餐仅供查看并禁用；刷新后恢复默认 Fake 状态。
- `noRecommendation`：系统推荐入口显示“暂无推荐”并禁用，但会员仍可手动查看可订套餐；不把“无推荐”误判为全场售罄。
- 已有预订、支付与凭证按钮只显示本地 Fake 结果，不进入尚未实现的真实支付或票据服务。
