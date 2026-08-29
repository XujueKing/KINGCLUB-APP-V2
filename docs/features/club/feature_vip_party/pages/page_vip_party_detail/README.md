# VIP 组局列表/详情页

- Scope ID：`KC-P-030`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[VIP 组局](../../README.md)
- 旧版来源：`Choose2`
- 路由：`VipPartyDetailRoute`，`/club/parties`，可选 `$extra: PartyRef`
- 设计版本：`VIP Party Legacy Replica v2 / Browse`
- 最后更新：2026-08-27

## 用户任务与线框

按营业日浏览组局，在旧版同页展开结构中查看安全详情，并根据自己的角色加入、继续支付或进入局长管理。

```text
[返回]              VIP组局
[今天] [周三] [周四] ...

[08.26 预选卡座和套餐] [预定一个新卡座]
[V8 / 时间 / KINGCLUB] [席位格 / 套餐 / 价格 / 二维码]
[点击后原位展开黑金成员区：局长 / 已加入会员 / 空置 / 允许动作]
[规则、不得退座、营业时间]
```

- 同一逻辑页面承担列表与详情；手机按旧版 `Choose2` 在卡片原位展开，不另做现代全屏详情层。
- 公开 viewer 不看成员名单；已确认 participant/host 才显示本局成员公开资料。
- inviteOnly 只有有效目标邀请才能打开详情，不在公开列表出现。
- 加入前必须显示本人权威应付、规则和取消政策；无付款能力时也必须服务端确认容量。
- 200% 字体下卡片纵向扩展，费用策略、状态和主按钮均具备明确读屏名称。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。

旧版视觉准则见 [legacy_ui_replication.md](legacy_ui_replication.md)。

## Android UI/Fake 实现证据

- 默认旧版组局页：[android_vip_legacy_replica_v2.png](android_vip_legacy_replica_v2.png)
- 局长同页展开与邀请：[android_vip_host_expanded_v2.png](android_vip_host_expanded_v2.png)
- viewer 同页展开与申请加入：[android_vip_viewer_expanded_v2.png](android_vip_viewer_expanded_v2.png)
- 付费加入规则确认：[android_vip_join_confirm_v2.png](android_vip_join_confirm_v2.png)
- Fake 待支付结果：[android_vip_pending_payment_v2.png](android_vip_pending_payment_v2.png)
- 已实现日期切换、展开/收起、局长邀请、viewer 申请、成员各付待支付、局长请客零元加入、空态、离线和满员 Fake 状态。
- 页面未显示微信胶囊或 `UI MOCK` 标签，未连接超级接口、WebSocket、支付或生产 SDK。

## 2026-08-29 黑金视觉修订

- 用户明确要求本页不得出现粉色；原位展开成员区、席位状态、头像、角色文案及动作按钮统一改为黑曜石、深棕和香槟金。
- 展开区保持原有成员顺序、邀请、申请加入、管理组局和返回逻辑，不因换色改变任务或状态机。
- 已占用席位以香槟金实底表达，空位使用深棕低对比底；按钮使用香槟金胶囊和深色文字。
