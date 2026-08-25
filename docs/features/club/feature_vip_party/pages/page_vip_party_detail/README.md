# VIP 组局列表/详情页

- Scope ID：`KC-P-030`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[VIP 组局](../../README.md)
- 旧版来源：`Choose2`
- 路由：`VipPartyDetailRoute`，`/club/parties`，可选 `$extra: PartyRef`
- 设计版本：`VIP Party Wireframe v1 / Browse`
- 最后更新：2026-08-25

## 用户任务与线框

按营业日浏览组局，打开安全详情，并根据自己的角色加入、继续支付或进入局长管理。

```text
[返回]              VIP 组局              [创建]
[今天] [周三] [周四] ...

[组局卡]
[局长头像] 公开昵称 · 已认证会员
8月25日 20:30—次日04:00     招募中 / 少量名额
套餐摘要                    成员各付 ¥388/人
[公开] [一人一席] [查看详情]

---- 详情层 / 选中卡展开 ----
局长公开资料 / 时间 / 套餐 / 费用明细 / 规则
当前 6～8 人（模糊区间）
[查看规则]                    [申请加入]
```

- 同一逻辑页面承担列表与详情；手机使用全屏详情层，宽屏可使用主从布局。
- 公开 viewer 不看成员名单；已确认 participant/host 才显示本局成员公开资料。
- inviteOnly 只有有效目标邀请才能打开详情，不在公开列表出现。
- 加入前必须显示本人权威应付、规则和取消政策；无付款能力时也必须服务端确认容量。
- 200% 字体下卡片纵向扩展，费用策略、状态和主按钮均具备明确读屏名称。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
