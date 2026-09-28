# 旧业务逻辑保留与数据库草案对照

更正：扩大扫描已找到 kingclubProfileAssets.cashBalance、goldCoin、diamond 及实际 profile-service 引用；之前 wallet 名称搜索结果不能用作“没有资产表”的依据。详见 [复用审查](REUSE_REVIEW.md)，还包含已有 031–034 部署记录；本轮未实时连接数据库。

2026-09-18，In Review。用户最新强调：旧系统虽不完整，业务逻辑是正确的。数据库工作以旧逻辑为基础补完整；不能因为前端/事务实现有缺口就否定原业务模型。用户已经明确的新规则继续优先，包括先报名后分座、30 分钟 AA 退款到余额、存酒资格及多店隔离。

## 本轮重新核对的证据

- 旧小程序 `pages/shoping2/shoping2.js:65` 调用 S231202506080736，读取券列表、金币和余额，并区分 actualAmount、payableAmount、discountAmount、payAmount。保留付款时选权益、区分应付/优惠/实际支付的逻辑，不简化成只有订单总价。
- `pages/order-manage/order-manage.js:211` 通过 S231202505150716 按 detailId 修改 goodsStatus。保留逐商品上菜确认与付款分离，不把上菜动作重复计为销售或整单出库。
- `pages/getWine/getWine.js` 以 storedId 和会员引用进入取酒流程。存酒是具体保管记录，不按酒名聚合后直接扣任意一瓶。
- 之前已完成的 SQL/Java 证据见 [旧审计](../LEGACY_AUDIT.md) 和 [字段盘点](../DATA_INVENTORY.md)，本轮未重新执行 SQL 或遍历 9 GB 业务数据。旧表逻辑结论与本次前端重新核对的证据分开标注，不声称全链路重新验证。

## 必须保留、补齐的关系

| 旧逻辑 | 新草案对照 | 下一步要求 |
|---|---|---|
| k_order 桌台/预约聚合 | table_session | 保留一次开台聚合；活动报名池是用户新要求，不覆盖开台语义 |
| k_stand_order 一次业务支付单 | sales_order / AA 与 payment_fact 之间尚未完整表达 | 必须补独立业务支付意图/支付组成，不能把标准单直接当渠道流水删掉 |
| k_transaction、通知与支付回调 | payment_fact 目前只有确认实收 | 补支付尝试/通知去重/状态查询；一笔业务允许重试渠道尝试但只结算一次 |
| k_order_detail 单品与上菜 | sales_line、shared_package | 补逐行交付事实，保留上菜操作历史与数量，不只整桌一个状态 |
| k_goods_detail 套餐组成 | recipe_version、recipe_line | 保留商品与组成关系，新增版本/单位保护，不改变共享套餐业务含义 |
| k_batch 与出入记录 | stock_batch、receipt、movement | 保留批次与来源；把收货、实际出库、盘点缺失部分补齐 |
| k_wallet / 余额金币券 / 账单 | 当前未建完整资金与券表 | 分清现金余额、赠送/金币、券、佣金；不能全部塞进一个现金余额 |
| 存酒与取用记录 | storage_holding_link + 现有储物服务 | 保留原记录归属与剩余量，新门店/来源资格是补充，不能新增第二份保管数量 |

首批 35 张 SQL 草案是候选结构，**尚未通过旧业务逻辑逐项对照**；尤其支付标准单、支付组成、交付明细仍不完整。在这些关系对齐前不得作为正式建表迁移。

## 新服务衔接核对

只读 `031_kingclub_private_storage.sql` 及 `src/kingclub/storage/storage-service.ts`：已有 holding/pickup/event，取码保存令牌哈希并绑定会话/版本、30 秒有效；quantity 与 remainingPercent 是现有模型。新 support SQL 只加来源/门店关联，不再存一份可独立修改的保管数量。legacy_item_ref 指现有新服务 holding 的 itemRef，名称仅为适配引用，**不是导入旧数据**。

`034_kingclub_registration_reward.sql` 是注册金币/经验一次性奖励凭据，不能充当现金钱包。此次在新服务 src/kingclub 及 database/mysql8 范围搜索 wallet/Wallet/assetBalance/coinBalance 未找到匹配现金钱包实现；这是有限搜索结果，不断言整个项目不存在钱包。钱包新建或复用需要继续沿旧支付/余额过程与新接口查询核实。

现有 storageProduct 的 category 仅 wine/item，maximumValue 字段不能证明已经实现本期完整抵扣券/折扣券规则。先核对旧券计算，再决定券表扩展，不拿显示字段代替真实权益账。

## 后续方式

按“旧页面 → 旧服务/SQL → 业务规则 → 新表与字段 → 必须保留的验收例子”逐条对齐，列出保留/补充/按用户新要求调整三类。旧实现的客户端可信输入、无并发锁等技术问题可以修，但不能以修技术问题为理由删掉原业务环节。暂不继续无依据扩表或注册正式接口。
