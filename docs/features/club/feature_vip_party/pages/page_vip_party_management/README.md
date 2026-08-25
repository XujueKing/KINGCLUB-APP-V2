# 局长组局管理页

- Scope ID：`KC-P-032`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[VIP 组局](../../README.md)
- 旧版来源：`order-manage`
- 路由：`VipPartyManagementRoute`，`/club/parties/manage`，`$extra: PartyRef`
- 设计版本：`VIP Party Wireframe v1 / Management`
- 最后更新：2026-08-25

## 用户任务与线框

局长查看组局概况、成员和邀请，管理招募及未完成邀请，并进入订单或追加点单后续流程。

```text
[返回]               组局管理
[招募中] 8月25日 20:30—次日04:00
套餐 / 成员各付 / 6～8人 / 公开

[概况] [成员与邀请] [消费摘要]

概况：
招募状态                              [关闭招募]
当前人数 / 容量 / 锁定时间
核心配置已锁定

成员与邀请：
[头像] 昵称 · 已确认                       [查看]
[头像] 昵称 · 待付款                    [释放占位]
[头像] 昵称 · 已邀请                    [撤销邀请]
                                      [邀请好友]

消费摘要：已付/待付/追加点单摘要
                                      [查看订单]
```

- 不显示手机号、实名、成员余额或个人支付明细。
- 不提供已付款成员“踢人”、固定赔付、转让局长、员工订单状态、服务员分配或商品确认开关。
- 套餐、费用方式、容量和核心规则建局后只读；可见性/招募开关也仅按 allowedActions 展示。
- 邀请好友一次只选一个联系人并二次确认；联系人选择使用受控 `ShareIntentRef`，提交成功后才生成绑定目标的 `PartyInviteRef`。
- 点单入口仅在营业日和服务端允许时出现，并等待 KC-P-034 批准。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
