# 门店收藏与收银会员接口

## APP 接入

统一超级接口 `K261005000810`，adapter `kingclub-store-favourites`，现有加密会员会话。

- `{action:"list"}` → `{result:{stores:[{storeRef,storeName,createdDate}]}}`
- `{action:"follow",storeRef}` → 同上，幂等收藏。
- `{action:"unfollow",storeRef}` → 同上，取消收藏不动余额和订单。

用户身份从会话提取，禁止入参选择 userAccount。门店必须存在且启用。列表最多500店。APP 门店页新增收藏按钮，进入或回前台重新读取列表；收藏成功后刷新按钮。收银扫码加入与 APP 收藏读取的是同一张关系表，无需另做同步名单。APP 界面本批未修改，交由 APP 会话按本契约接入。

## 收银端

`K261005002010`，adapter `kingclub-cashier-store-members`。所有操作带当前员工授权 storeRef，沿用收银 API key 范围及实时门店权限校验。

- list：可传 after 用户账号游标；返回50个 members 和 nextAfter。
- link：identityCode 为动态 KC:M 会员身份码；验证会话和会员有效后幂等入会，直接返回详情。扫码原文不保存。
- detail：userAccount 必须已关联本店；返回 member、balance、history、campaigns。
- campaignSave：price.adjust 权限；campaign 带 revision、principalCents、giftCents、enabled、可选 campaignRef。旧版停用，新增版本；旧充值金额和条款不改写。
- prepare：对应渠道收款权限；userAccount、requestId UUID、campaignRef、campaignRevision、channel。创建未付款原充值单，后续沿用 K260930001933/934 收款/查单。原请求重试不重复建单。
- refundQuote/refund/refundQuery：payment.refund 权限；userAccount、rechargeRef；refund 还需 requestId、expectedRefundCents。报价不动账；金额变化拒绝提交。pending 不等于退款成功。

member 使用 userAccount、nickname、avatarBase64、phone（暂无号码来源时 null）；balance 本金与赠送分列。退款后通过已有 member balance outbox 通知 APP。成功前禁止客户端自行增减余额。

渠道配置只读统一支付源；本店充值采用 merchant_direct，会员储值属于客户负债，不增加商户虚拟归集余额。后台配置开关和真实渠道测试与代码验收分开记录。
