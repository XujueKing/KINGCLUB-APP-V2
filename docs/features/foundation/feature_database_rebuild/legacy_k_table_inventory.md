# 旧 `k_` 表清单与领域归属

- 来源：`C:\Users\Poplar\Desktop\datebase\nuggets-仅结构.sql`
- 表数：94
- 字段数：1,484
- 数据库外键数：0
- 状态：初步归属，In Review

## 身份与资料（5）

`k_user`、`k_user_info`、`k_user_examine_images`、`k_user_examine_type`、`k_user_setting`

处理方向：拆为平台身份、登录身份、App 成员、公开资料、敏感资料、KYC/审核和匹配偏好。

## 社交关系（4）

`k_user_follow`、`k_user_relation`、`k_user_setup`、`k_conversations_blacklist`

处理方向：关注、好友、黑名单、备注和可见性分别建模；禁止继续把关注集合保存在 LongText。

## 消息与通知（9）

`k_conversations`、`k_conversations_group_temp`、`k_conversations_messages`、`k_conversations_messages_attachments`、`k_conversations_messages_collect`、`k_conversations_messages_reads`、`k_conversations_temp`、`k_push_log`、`k_system_messages`

处理方向：会话、参与者、消息、附件、送达/已读状态、用户会话设置和推送任务分表。

## 内容与活动（20）

`k_activity`、`k_activity_join`、`k_ad_info`、`k_advertisement`、`k_advertisement_log`、`k_collect_log`、`k_content_log`、`k_like_log`、`k_question_answer`、`k_question_options`、`k_questionnaire`、`k_questions`、`k_subject`、`k_tweets`、`k_tweets_log`、`k_user_comment`、`k_user_comment_image`、`k_user_like_praise_collect`、`k_user_works`、`k_user_works_files`

处理方向：先确认 V2 MVP 是否包含，再决定迁移历史数据或只保留只读归档。

## 门店、商品与库存（25）

`k_batch`、`k_closed_date_config`、`k_division`、`k_goods`、`k_goods_access_log`、`k_goods_batch`、`k_goods_classification`、`k_goods_detail`、`k_goods_property`、`k_goods_warehouse_location`、`k_items_goods`、`k_items_goods_log`、`k_prop`、`k_prop_function_item`、`k_shop_thing`、`k_shop_thing_check_log`、`k_shop_thing_classify`、`k_stored_items`、`k_stored_items_log`、`k_stored_wine`、`k_table`、`k_thali`、`k_virtual_goods`、`k_virtual_goods_log`、`k_warehouse`

处理方向：门店目录、商品 SKU、库存批次、桌台/座位、存酒和虚拟商品分别建模。

## 订单与履约（11）

`k_bill_detail`、`k_order`、`k_order_detail`、`k_order_member`、`k_order_temp`、`k_remark_detail`、`k_rule_note`、`k_sign_qrcode`、`k_stand_order`、`k_stand_order_type`、`k_ticket_records`

处理方向：先画清组局/一起玩/扫码点单/门票状态机，再设计订单主表和履约子域。

## 资产、支付与结算（18）

`k_balance_details`、`k_bank_card`、`k_commission_log`、`k_coupon`、`k_coupon_log`、`k_diamond_detail`、`k_drinks_access_log`、`k_exp_detail`、`k_goldcoin_detail`、`k_level_config`、`k_level_score_detail`、`k_recharge_config`、`k_recharge_details`、`k_refund_transaction`、`k_transaction`、`k_transaction_notify`、`k_wallet`、`k_withdrawal`

处理方向：钱包账户、不可变账本、支付订单、支付尝试、回调、退款、提现、优惠券和成长资产分离；所有金额必须独立对账。

## 平台配置（2）

`k_config`、`k_invitation_code`

处理方向：配置需要明确环境、版本、启停和审计；邀请码归入会员增长域。

## 重点旧表问题

| 旧表 | 问题 | V2 方向 |
|---|---|---|
| `k_user` | 凭据、PII、资料、会员、推送、在线状态混表 | 拆分平台身份、App 成员、资料、KYC、设备/会话 |
| `k_user_follow` | 关注集合为 LongText | 一行一条有向关系 |
| `k_conversations` | 成员和管理员为逗号集合，保存会话密码 | 会话与参与者分表，不保存客户端共享密码 |
| `k_conversations_messages` | 全局消息状态与群已读集合混合 | 消息、送达、已读游标/回执分离 |
| `k_order` | 订单、组局规则、桌台和计价结果混合 | 订单聚合与活动/预约规则分离 |
| `k_wallet` | 当前余额可直接更新 | 账本为事实，余额为受控快照 |
| `k_transaction` | 支付、结算、回调、订单快照混合 | 支付订单、尝试、回调、对账和结算分离 |

