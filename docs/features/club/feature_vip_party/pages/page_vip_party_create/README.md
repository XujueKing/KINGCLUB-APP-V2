# VIP 组局创建页

- Scope ID：`KC-P-031`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[VIP 组局](../../README.md)
- 旧版来源：`vip-order`
- 路由：`VipPartyCreateRoute`，`/club/parties/create`，`$extra: ServiceDayRef`
- 设计版本：`VIP Party Wireframe v1 / Create`
- 最后更新：2026-08-25

## 用户任务与线框

为选定营业日配置桌位套餐、人数、费用和可见性，核对服务端报价与责任后创建组局。

```text
[取消]             创建 VIP 组局

[日期] 8月25日 20:30—次日04:00
[卡座与套餐]                              [选择 >]
[计划人数] 8 人                            [选择 >]

[费用方式]
(●) 成员各付   每位成员加入时按权威报价付款
( ) 局长请客   局长承担当前报价的主办费用

[可见范围]
(●) 公开招募   ( ) 仅邀请

[报价明细]
套餐/服务/活动优惠/局长本次应付/成员参考应付
报价剩余 04:58

[ ] 已阅读组局、费用、取消和安全规则 [查看]
局长本次应付 ¥xxxx                    [确认创建]
```

- 不提供是否做局长、颜值、性别比例和自定义年龄筛选。
- 桌位、套餐、容量、费用策略或可见性变化都触发完整服务端重报价。
- 抵扣方案若未来开放，也只能选择服务端方案，不允许手输或本地计算。
- 创建成功可能返回待支付或免付确认；支付过程归 KC-P-038。
- 页面不承诺建局前库存已锁定，提交时仍需原子校验。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
