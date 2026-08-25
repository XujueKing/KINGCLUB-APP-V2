# VIP 组局流程与导航

## 浏览与加入

```text
Home / Party business card
  -> VipPartyDetailRoute(PartyRef?)
  -> 选择营业日 / 组局
  -> 查看规则、局长摘要、费用和模糊余量
  -> 确认加入规则
  -> createJoinIntent(idempotencyKey)
  -> hostSponsored: confirmed
  -> splitPerMember: PaymentRoute(PaymentIntentRef)
  -> 回组局详情重读成员状态
```

## 创建与管理

```text
VipPartyDetailRoute
  -> VipPartyCreateRoute(ServiceDayRef)
  -> 配置桌位套餐、容量、费用策略、可见性
  -> 服务端报价 + 规则确认
  -> createParty(idempotencyKey)
  -> PaymentRoute / confirmed
  -> VipPartyManagementRoute(PartyRef)

Management
  -> 发送邀请：ContactSelectorRoute(ShareIntentRef: businessCard)
  -> 关闭/开启招募
  -> 撤销未接受邀请 / 释放未付款占位
  -> 查看消费者订单摘要或进入点单页面
```

## 返回与异常

- 浏览页返回来源；选中详情属于同一页面状态，返回优先关闭详情层，再退出页面。
- 创建页未提交可返回并保存本次会话草稿；提交结果未知先对账，不能重建。
- 管理页失去 host 权限时立即变只读并返回详情，不继续显示敏感成员信息。
- 邀请过期、撤销、被转发给非目标人时安全拒绝并回公开详情/首页。
- 下游支付、订单、票据和点单页面尚未批准时仅保留类型化意图与 Mock 出口。

## 路由引用

```text
PartyRef        refId, generation
ServiceDayRef   refId, generation, expiresAt
PartyDraftRef   refId, generation, revision, expiresAt
PartyInviteRef  refId, generation, targetMemberRef, expiresAt
```

禁止在 path/query 传账号、日期、成员、金额、桌位、套餐、邀请资格或订单 JSON。
