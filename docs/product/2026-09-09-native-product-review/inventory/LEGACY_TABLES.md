# KING CLUB 表级归属与字段清单

- 已确认事实：混合快照 515 张表中，94 张 `k_` 表是本轮 KING CLUB 业务数据盘点范围，共 1484 个字段。
- 后续群聊脚本另有 `k_conversation_member`、`k_group_join_request` 两张候选增量表；不声称线上当前恰好 96 张。
- 归属列是当前建议，跨域关系/财务/运营表需要逐表映射评审；首发 UI 暂缓不等于可以删除其数据。
- INSERT 数是文件里的 INSERT 语句数，不是已验证数据库行数；0 不证明生产为空。没有读取或导出业务字段值。
- 比较只覆盖字段名/基本类型/空值、索引标识、引擎、默认字符集，不证明 Routine、触发器或完整 DDL 相同。
- 导出快照无 k_ 外键，87 张默认 utf8、7 张默认 utf8mb4；重建时验证逻辑引用、Unicode 和金额精度。

| # | 旧表 | 建议业务归属 | 字段数 | 默认字符集 | 快照 INSERT 语句数 | 与仅结构文件比较 |
|---:|---|---|---:|---|---:|---|
| 1 | `k_activity` | 运营、规则与活动配置 | 14 | utf8 | 0 | 结构元数据相同 |
| 2 | `k_activity_join` | 运营、规则与活动配置 | 9 | utf8 | 0 | 结构元数据相同 |
| 3 | `k_ad_info` | 运营、规则与活动配置 | 22 | utf8mb4 | 7 | 结构元数据相同 |
| 4 | `k_advertisement` | 运营、规则与活动配置 | 13 | utf8 | 0 | 结构元数据相同 |
| 5 | `k_advertisement_log` | 运营、规则与活动配置 | 9 | utf8 | 0 | 结构元数据相同 |
| 6 | `k_balance_details` | 支付、资产与财务（部分仅后台） | 24 | utf8 | 1409 | 结构元数据相同 |
| 7 | `k_bank_card` | 支付、资产与财务（部分仅后台） | 15 | utf8 | 6 | 结构元数据相同 |
| 8 | `k_batch` | 商品、库存与仓储后台 | 13 | utf8 | 1 | 结构元数据相同 |
| 9 | `k_bill_detail` | 支付、资产与财务（部分仅后台） | 11 | utf8mb4 | 4407 | 结构元数据相同 |
| 10 | `k_closed_date_config` | 门店、预约、组局与入场 | 10 | utf8 | 2 | 结构元数据相同 |
| 11 | `k_collect_log` | 作品、评论与内容互动 | 9 | utf8 | 0 | 结构元数据相同 |
| 12 | `k_commission_log` | 支付、资产与财务（部分仅后台） | 13 | utf8 | 0 | 结构元数据相同 |
| 13 | `k_config` | 运营、规则与活动配置 | 12 | utf8 | 13 | 结构元数据相同 |
| 14 | `k_content_log` | 作品、评论与内容互动 | 14 | utf8 | 0 | 结构元数据相同 |
| 15 | `k_conversations` | 聊天、通知与群管理 | 19 | utf8 | 65 | 结构元数据相同 |
| 16 | `k_conversations_blacklist` | 聊天、通知与群管理 | 9 | utf8 | 0 | 结构元数据相同 |
| 17 | `k_conversations_group_temp` | 聊天、通知与群管理 | 16 | utf8 | 0 | 结构元数据相同 |
| 18 | `k_conversations_messages` | 聊天、通知与群管理 | 19 | utf8mb4 | 3872 | 结构元数据相同 |
| 19 | `k_conversations_messages_attachments` | 聊天、通知与群管理 | 11 | utf8 | 0 | 结构元数据相同 |
| 20 | `k_conversations_messages_collect` | 聊天、通知与群管理 | 10 | utf8mb4 | 2 | 结构元数据相同 |
| 21 | `k_conversations_messages_reads` | 聊天、通知与群管理 | 9 | utf8 | 0 | 结构元数据相同 |
| 22 | `k_conversations_temp` | 聊天、通知与群管理 | 16 | utf8 | 67 | 结构元数据相同 |
| 23 | `k_coupon` | 支付、资产与财务（部分仅后台） | 16 | utf8 | 2 | 结构元数据相同 |
| 24 | `k_coupon_log` | 支付、资产与财务（部分仅后台） | 10 | utf8 | 0 | 结构元数据相同 |
| 25 | `k_diamond_detail` | 支付、资产与财务（部分仅后台） | 16 | utf8 | 665 | 结构元数据相同 |
| 26 | `k_division` | 关系、代理归属与备注（需拆权） | 10 | utf8 | 374 | 结构元数据相同 |
| 27 | `k_drinks_access_log` | 会员物品、存酒与领取 | 18 | utf8 | 1 | 结构元数据相同 |
| 28 | `k_exp_detail` | 身份、会员与个人资料 | 10 | utf8 | 4998 | 结构元数据相同 |
| 29 | `k_goldcoin_detail` | 支付、资产与财务（部分仅后台） | 16 | utf8 | 2501 | 结构元数据相同 |
| 30 | `k_goods` | 商品、库存与仓储后台 | 28 | utf8 | 45 | 结构元数据相同 |
| 31 | `k_goods_access_log` | 商品、库存与仓储后台 | 15 | utf8 | 0 | 结构元数据相同 |
| 32 | `k_goods_batch` | 商品、库存与仓储后台 | 23 | utf8 | 19 | 结构元数据相同 |
| 33 | `k_goods_classification` | 商品、库存与仓储后台 | 14 | utf8 | 22 | 结构元数据相同 |
| 34 | `k_goods_detail` | 商品、库存与仓储后台 | 16 | utf8 | 70 | 结构元数据相同 |
| 35 | `k_goods_property` | 商品、库存与仓储后台 | 26 | utf8 | 19 | 结构元数据相同 |
| 36 | `k_goods_warehouse_location` | 商品、库存与仓储后台 | 9 | utf8 | 0 | 结构元数据相同 |
| 37 | `k_invitation_code` | 身份、会员与个人资料 | 13 | utf8 | 200 | 结构元数据相同 |
| 38 | `k_items_goods` | 会员物品、存酒与领取 | 24 | utf8 | 2 | 结构元数据相同 |
| 39 | `k_items_goods_log` | 会员物品、存酒与领取 | 13 | utf8 | 0 | 结构元数据相同 |
| 40 | `k_level_config` | 身份、会员与个人资料 | 13 | utf8 | 31 | 结构元数据相同 |
| 41 | `k_level_score_detail` | 身份、会员与个人资料 | 13 | utf8 | 0 | 结构元数据相同 |
| 42 | `k_like_log` | 作品、评论与内容互动 | 10 | utf8 | 0 | 结构元数据相同 |
| 43 | `k_order` | 门店、预约、组局与入场 | 32 | utf8 | 116 | 结构元数据相同 |
| 44 | `k_order_detail` | 门店、预约、组局与入场 | 18 | utf8 | 125 | 结构元数据相同 |
| 45 | `k_order_member` | 门店、预约、组局与入场 | 20 | utf8 | 181 | 结构元数据相同 |
| 46 | `k_order_temp` | 门店、预约、组局与入场 | 37 | utf8 | 58 | 结构元数据相同 |
| 47 | `k_prop` | 运营、规则与活动配置 | 10 | utf8 | 0 | 结构元数据相同 |
| 48 | `k_prop_function_item` | 运营、规则与活动配置 | 10 | utf8 | 0 | 结构元数据相同 |
| 49 | `k_push_log` | 聊天、通知与群管理 | 13 | utf8 | 3159 | 结构元数据相同 |
| 50 | `k_question_answer` | 运营、规则与活动配置 | 10 | utf8 | 0 | 结构元数据相同 |
| 51 | `k_question_options` | 运营、规则与活动配置 | 11 | utf8 | 0 | 结构元数据相同 |
| 52 | `k_questionnaire` | 运营、规则与活动配置 | 13 | utf8 | 0 | 结构元数据相同 |
| 53 | `k_questions` | 运营、规则与活动配置 | 11 | utf8 | 0 | 结构元数据相同 |
| 54 | `k_recharge_config` | 支付、资产与财务（部分仅后台） | 10 | utf8 | 8 | 结构元数据相同 |
| 55 | `k_recharge_details` | 支付、资产与财务（部分仅后台） | 15 | utf8 | 0 | 结构元数据相同 |
| 56 | `k_refund_transaction` | 支付、资产与财务（部分仅后台） | 28 | utf8 | 0 | 结构元数据相同 |
| 57 | `k_remark_detail` | 关系、代理归属与备注（需拆权） | 11 | utf8mb4 | 0 | 结构元数据相同 |
| 58 | `k_rule_note` | 运营、规则与活动配置 | 10 | utf8mb4 | 2 | 结构元数据相同 |
| 59 | `k_shop_thing` | 商品、库存与仓储后台 | 13 | utf8 | 0 | 结构元数据相同 |
| 60 | `k_shop_thing_check_log` | 商品、库存与仓储后台 | 13 | utf8 | 0 | 结构元数据相同 |
| 61 | `k_shop_thing_classify` | 商品、库存与仓储后台 | 13 | utf8 | 0 | 结构元数据相同 |
| 62 | `k_sign_qrcode` | 门店、预约、组局与入场 | 9 | utf8 | 4 | 结构元数据相同 |
| 63 | `k_stand_order` | 支付、资产与财务（部分仅后台） | 28 | utf8 | 242 | 结构元数据相同 |
| 64 | `k_stand_order_type` | 支付、资产与财务（部分仅后台） | 11 | utf8 | 15 | 结构元数据相同 |
| 65 | `k_stored_items` | 会员物品、存酒与领取 | 18 | utf8 | 414 | 结构元数据相同 |
| 66 | `k_stored_items_log` | 会员物品、存酒与领取 | 14 | utf8 | 1358 | 结构元数据相同 |
| 67 | `k_stored_wine` | 会员物品、存酒与领取 | 20 | utf8 | 5 | 结构元数据相同 |
| 68 | `k_subject` | 作品、评论与内容互动 | 10 | utf8 | 2 | 结构元数据相同 |
| 69 | `k_system_messages` | 聊天、通知与群管理 | 11 | utf8mb4 | 2621 | 结构元数据相同 |
| 70 | `k_table` | 门店、预约、组局与入场 | 16 | utf8 | 16 | 结构元数据相同 |
| 71 | `k_thali` | 门店、预约、组局与入场 | 13 | utf8 | 5 | 结构元数据相同 |
| 72 | `k_ticket_records` | 门店、预约、组局与入场 | 11 | utf8 | 133 | 结构元数据相同 |
| 73 | `k_transaction` | 支付、资产与财务（部分仅后台） | 33 | utf8 | 311 | 结构元数据相同 |
| 74 | `k_transaction_notify` | 支付、资产与财务（部分仅后台） | 14 | utf8 | 258 | 结构元数据相同 |
| 75 | `k_tweets` | 运营、规则与活动配置 | 14 | utf8 | 0 | 结构元数据相同 |
| 76 | `k_tweets_log` | 运营、规则与活动配置 | 10 | utf8 | 0 | 结构元数据相同 |
| 77 | `k_user` | 身份、会员与个人资料 | 41 | utf8 | 761 | 结构元数据相同 |
| 78 | `k_user_comment` | 作品、评论与内容互动 | 13 | utf8 | 0 | 结构元数据相同 |
| 79 | `k_user_comment_image` | 作品、评论与内容互动 | 12 | utf8 | 0 | 结构元数据相同 |
| 80 | `k_user_examine_images` | 身份、会员与个人资料 | 15 | utf8 | 1649 | 结构元数据相同 |
| 81 | `k_user_examine_type` | 身份、会员与个人资料 | 9 | utf8 | 32 | 结构元数据相同 |
| 82 | `k_user_follow` | 关系、代理归属与备注（需拆权） | 10 | utf8 | 3 | 结构元数据相同 |
| 83 | `k_user_info` | 身份、会员与个人资料 | 36 | utf8 | 0 | 结构元数据相同 |
| 84 | `k_user_like_praise_collect` | 作品、评论与内容互动 | 12 | utf8 | 0 | 结构元数据相同 |
| 85 | `k_user_relation` | 关系、代理归属与备注（需拆权） | 16 | utf8 | 342 | 结构元数据相同 |
| 86 | `k_user_setting` | 身份、会员与个人资料 | 25 | utf8 | 0 | 结构元数据相同 |
| 87 | `k_user_setup` | 身份、会员与个人资料 | 23 | utf8 | 142 | 结构元数据相同 |
| 88 | `k_user_works` | 作品、评论与内容互动 | 26 | utf8 | 14 | 结构元数据相同 |
| 89 | `k_user_works_files` | 作品、评论与内容互动 | 16 | utf8 | 36 | 结构元数据相同 |
| 90 | `k_virtual_goods` | 支付、资产与财务（部分仅后台） | 22 | utf8 | 201 | 结构元数据相同 |
| 91 | `k_virtual_goods_log` | 支付、资产与财务（部分仅后台） | 16 | utf8 | 128 | 结构元数据相同 |
| 92 | `k_wallet` | 支付、资产与财务（部分仅后台） | 11 | utf8 | 2825 | 结构元数据相同 |
| 93 | `k_warehouse` | 商品、库存与仓储后台 | 21 | utf8 | 30 | 结构元数据相同 |
| 94 | `k_withdrawal` | 支付、资产与财务（部分仅后台） | 20 | utf8 | 1 | 结构元数据相同 |

## 字段级原始结构索引（不是已批准的新库字段映射）

### k_activity

`rowId: int(11)`、`id: varchar(255)`、`activityId: varchar(255)`、`title: varchar(255)`、`content: longtext`、`coverImage: varchar(255)`、`startDate: datetime(3)`、`endDate: datetime(3) nullable`、`status: int(1)`、`operateUserId: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_activity_join

`rowId: int(11)`、`id: varchar(255)`、`joinId: varchar(255)`、`userAccount: varchar(255)`、`activityId: varchar(255)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_ad_info

`rowId: int(11)`、`id: varchar(255)`、`adId: varchar(255)`、`adTitle: varchar(255) nullable`、`adImage: varchar(255) nullable`、`content: longtext nullable`、`typeId: int(1)`、`exUrl: varchar(255) nullable`、`modeId: int(1)`、`isTop: int(1)`、`visitNum: int(10)`、`likeNum: int(10)`、`unLikeNum: int(10)`、`contentNum: int(10)`、`collectNum: int(10)`、`registerId: varchar(255)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`、`isBanner: int(1)`、`bannerImg: varchar(255) nullable`

### k_advertisement

`rowId: int(11)`、`id: varchar(255)`、`advertisementId: varchar(255)`、`title: varchar(255)`、`content: longtext nullable`、`src: varchar(255) nullable`、`exData: longtext nullable`、`operateUserId: varchar(255) nullable`、`visits: int(10) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_advertisement_log

`rowId: int(11)`、`id: varchar(255)`、`logId: varchar(255)`、`advertisementId: varchar(255)`、`userAccount: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_balance_details

`rowId: int(11)`、`id: varchar(255)`、`detailsId: varchar(255)`、`walletId: varchar(255)`、`userAccount: varchar(255) nullable`、`income: decimal(10,2)`、`expense: decimal(10,2)`、`balance: decimal(10,2)`、`detailsType: int(2)`、`accountType: int(2)`、`detailsProperty: int(2)`、`detailsSubProperty: int(2)`、`counterparty: varchar(255)`、`otherUserAccount: varchar(255) nullable`、`relationId: varchar(255) nullable`、`detailsStatus: varchar(255)`、`detailsThawDate: datetime(3) nullable`、`outTradeNo: varchar(255) nullable`、`tradeNo: varchar(255) nullable`、`detailsRemarks: longtext nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_bank_card

`rowId: int(11)`、`id: varchar(255)`、`cardId: varchar(255)`、`userAccount: varchar(255)`、`cardNumber: varchar(255)`、`bankName: varchar(255)`、`bankFullName: varchar(255)`、`cardMobile: varchar(255)`、`bankAddress: varchar(255) nullable`、`isDefault: int(1)`、`userName: varchar(255)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_batch

`rowId: int(11)`、`id: varchar(255)`、`batchId: varchar(255)`、`batchRequestId: varchar(255)`、`batchPurchaseId: varchar(255) nullable`、`batchCheckId: varchar(255) nullable`、`batchLeaderId: varchar(255) nullable`、`batchStoreId: varchar(255) nullable`、`batchRequestDate: datetime(3) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_bill_detail

`rowId: int(11)`、`id: varchar(255)`、`billId: varchar(255)`、`userAccount: varchar(255)`、`typeId: int(1)`、`content: longtext nullable`、`billStaus: int(1)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_closed_date_config

`rowId: int(11)`、`id: varchar(255)`、`configId: varchar(255)`、`closedDate: datetime(3)`、`remarks: longtext nullable`、`registerId: varchar(255)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_collect_log

`rowId: int(11)`、`id: varchar(255)`、`collectId: varchar(255)`、`relationId: varchar(255)`、`userAccount: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_commission_log

`rowId: int(11)`、`id: varchar(255)`、`logId: varchar(255)`、`orderId: varchar(255)`、`memberId: varchar(255)`、`userAccount: varchar(255)`、`proxyId: varchar(255) nullable`、`personType: int(2)`、`commissionPrice: decimal(10,2)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_config

`rowId: int(11)`、`id: varchar(255)`、`configId: varchar(255)`、`configTitle: varchar(255) nullable`、`configValue: varchar(500) nullable`、`valueType: int(1)`、`remarks: varchar(1000) nullable`、`configType: int(1)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_content_log

`rowId: int(11)`、`id: varchar(255)`、`contentId: varchar(255)`、`relationId: varchar(255)`、`content: longtext`、`userAccount: varchar(255) nullable`、`parentId: varchar(255)`、`likeNum: int(10)`、`unLikeNum: int(10)`、`contentNum: int(10)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_conversations

`rowId: int(11)`、`id: varchar(255)`、`conversationsId: varchar(255)`、`conversationsType: int(1)`、`memberIds: longtext`、`remarkName: varchar(255) nullable`、`groupUserId: varchar(255) nullable`、`groupName: varchar(255) nullable`、`topUp: int(1)`、`source: varchar(255) nullable`、`notice: longtext nullable`、`islnvitation: int(1)`、`isModify: int(1)`、`manageList: longtext nullable`、`passwordStr: varchar(255)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_conversations_blacklist

`rowId: int(11)`、`id: varchar(255)`、`blacklistId: varchar(255)`、`userAccount: varchar(255)`、`blockedUserAccount: longtext`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_conversations_group_temp

`rowId: int(11)`、`id: varchar(255)`、`tempId: varchar(255)`、`fromUserAccount: varchar(255)`、`initiationTime: datetime(3)`、`conversationsId: varchar(255)`、`remarkName: varchar(255) nullable`、`isAuth: int(2)`、`authTime: datetime(3) nullable`、`isRead: int(2)`、`source: varchar(255) nullable`、`remarks: longtext nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_conversations_messages

`rowId: int(11)`、`id: varchar(255)`、`messageId: varchar(255)`、`conversationsId: varchar(255)`、`senderId: varchar(255)`、`content: longtext`、`messageType: int(2)`、`messageStaus: int(1)`、`groupReadUsers: longtext nullable`、`parentId: varchar(255) nullable`、`extraData: varchar(255) nullable`、`picWidth: int(10)`、`picHeight: int(10)`、`thumbPic: varchar(255) nullable`、`videoTime: int(10)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_conversations_messages_attachments

`rowId: int(11)`、`id: varchar(255)`、`attachmentsId: varchar(255)`、`messageId: varchar(255)`、`fileUrl: varchar(255)`、`fileType: int(1)`、`fileSize: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_conversations_messages_collect

`rowId: int(11)`、`id: varchar(255)`、`collectId: varchar(255)`、`userAccount: varchar(255)`、`messageId: varchar(255)`、`label: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_conversations_messages_reads

`rowId: int(11)`、`id: varchar(255)`、`readId: varchar(255)`、`messageId: varchar(255)`、`userAccount: varchar(255)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_conversations_temp

`rowId: int(11)`、`id: varchar(255)`、`tempId: varchar(255)`、`fromUserAccount: varchar(255)`、`initiationTime: datetime(3)`、`toUserAccount: varchar(255)`、`remarkName: varchar(255) nullable`、`isAuth: int(2)`、`authTime: datetime(3) nullable`、`isRead: int(2)`、`source: varchar(255) nullable`、`remarks: longtext nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_coupon

`rowId: int(11)`、`id: varchar(255)`、`couponId: varchar(255)`、`couponTitle: varchar(255)`、`couponDescribe: longtext`、`couponType: int(2)`、`couponAmount: decimal(6,2)`、`startDate: datetime(3)`、`endDate: datetime(3) nullable`、`userAccount: varchar(255)`、`walletId: varchar(255)`、`isUsered: int(2)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_coupon_log

`rowId: int(11)`、`id: varchar(255)`、`logId: varchar(255)`、`fromUserAccount: varchar(255)`、`toUserAccount: varchar(255)`、`couponId: varchar(255)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_diamond_detail

`rowId: int(11)`、`id: varchar(255)`、`logId: varchar(255)`、`userAccount: varchar(255)`、`operateType: int(1)`、`income: int(11)`、`expense: int(11)`、`balance: int(11)`、`detailsProperty: int(2)`、`counterparty: varchar(255)`、`standOrderId: varchar(255) nullable`、`remarks: longtext nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_division

`rowId: int(11)`、`id: varchar(255)`、`divisionCode: varchar(255)`、`divisionName: varchar(255) nullable`、`step: int(11)`、`parentId: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_drinks_access_log

`rowId: int(11)`、`id: varchar(255)`、`storageId: varchar(255)`、`userAccount: varchar(255)`、`wineId: varchar(255)`、`wineName: varchar(255)`、`orderId: varchar(255) nullable`、`number: int(3)`、`percentage: decimal(10,2)`、`pic: varchar(255)`、`storageStatus: int(2)`、`takeDate: datetime(3) nullable`、`locationId: varchar(255) nullable`、`operateUserAccount: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_exp_detail

`rowId: int(11)`、`id: varchar(255)`、`expId: varchar(255)`、`userAccount: varchar(255)`、`expNum: int(11)`、`remarks: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_goldcoin_detail

`rowId: int(11)`、`id: varchar(255)`、`logId: varchar(255)`、`userAccount: varchar(255)`、`operateType: int(1)`、`income: int(11)`、`expense: int(11)`、`balance: int(11)`、`detailsProperty: int(2)`、`counterparty: varchar(255)`、`standOrderId: varchar(255) nullable`、`remarks: longtext nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_goods

`rowId: int(11)`、`id: varchar(255)`、`goodsId: varchar(255)`、`goodsName: varchar(255)`、`goodsFullName: varchar(255) nullable`、`barcode: varchar(255)`、`classificationId: varchar(255)`、`iconImage: varchar(500) nullable`、`appImage: varchar(500) nullable`、`goodsImage: varchar(255) nullable`、`describe: longtext`、`goodsProperty: int(2)`、`goodsStatus: int(2)`、`goodsRegistDate: datetime(3) nullable`、`registId: varchar(255) nullable`、`batchId: varchar(255) nullable`、`buyingPrice: decimal(10,2)`、`originalPrice: decimal(10,2)`、`discountPrice: decimal(10,2)`、`sorting: int(11)`、`svgWidth: decimal(10,2)`、`svgHeight: decimal(10,2)`、`svgImage: longtext nullable`、`goodsSpecs: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_goods_access_log

`rowId: int(11)`、`id: varchar(255)`、`storageId: varchar(255)`、`userAccount: varchar(255)`、`goodsId: varchar(255)`、`goodsName: varchar(255)`、`goodsType: varchar(255)`、`pic: varchar(255) nullable`、`type: int(2)`、`locationId: varchar(255) nullable`、`operateUserAccount: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_goods_batch

`rowId: int(11)`、`id: varchar(255)`、`goodsBathId: varchar(255)`、`goodsId: varchar(255)`、`barcode: varchar(255)`、`propertyId: varchar(255)`、`goodsPrice: decimal(16,2)`、`goodsMinPrice: decimal(16,2)`、`goodsCost: decimal(16,2)`、`batchPlanNumber: decimal(10,2)`、`batchRealityNumber: decimal(10,2)`、`batchSendNumber: decimal(10,2)`、`batchRequestDate: datetime(3)`、`batchCheckDate: datetime(3) nullable`、`batchFromDate: datetime(3) nullable`、`batchId: varchar(255) nullable`、`batchDesc: text nullable`、`registId: varchar(255) nullable`、`goodsStandPrice: decimal(10,2)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_goods_classification

`rowId: int(11)`、`id: varchar(255)`、`classificationId: varchar(255)`、`classificationType: int(1)`、`name: varchar(255)`、`describe: longtext`、`image: varchar(255) nullable`、`parentId: varchar(255) nullable`、`deep: int(2)`、`sorting: int(5)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_goods_detail

`rowId: int(11)`、`id: varchar(255)`、`detailId: varchar(255)`、`goodsId: varchar(255)`、`goodsName: varchar(255)`、`goodsNumber: int(2)`、`parentId: varchar(255)`、`buyingPrice: decimal(10,2)`、`originalPrice: decimal(10,2)`、`discountPrice: decimal(10,2)`、`sorting: int(11)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`、`unit: varchar(255) nullable`

### k_goods_property

`rowId: int(11)`、`id: varchar(255)`、`propertyId: varchar(255)`、`barcode: varchar(255)`、`sorting: int(11)`、`manufacturerId: varchar(255) nullable`、`companyId: varchar(255) nullable`、`goodsBody: text nullable`、`goodsPage: longtext nullable`、`goodsShelfLife: decimal(10,2)`、`goodsShelfLifeUnit: int(2)`、`goodsMinUnit: varchar(255) nullable`、`goodsSpecs: varchar(255) nullable`、`goodsColorRGB: varchar(255) nullable`、`goodsColorEn: varchar(255) nullable`、`goodsSizeLong: double`、`goodsSizeWidth: double`、`goodsSizeHeight: double`、`goodsWeight: decimal(10,4)`、`goodsWeightUnit: int(2)`、`propertyStatus: int(2)`、`goodsArea: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_goods_warehouse_location

`rowId: int(11)`、`id: varchar(255)`、`locationId: varchar(255)`、`name: varchar(255)`、`content: longtext`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_invitation_code

`rowId: int(11)`、`id: varchar(255)`、`codeId: varchar(255)`、`tableName: varchar(255)`、`number: varchar(255)`、`content: longtext`、`status: int(2)`、`mobile: varchar(255) nullable`、`operator: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_items_goods

`rowId: int(11)`、`id: varchar(255)`、`itemsId: varchar(255)`、`itemsName: varchar(255)`、`itemsFullName: varchar(255) nullable`、`itemsType: int(1)`、`iconImage: varchar(500) nullable`、`appImage: varchar(500) nullable`、`itemsImage: varchar(255) nullable`、`describe: longtext nullable`、`itemsStatus: int(1)`、`itemsProperty: int(1)`、`getPrice: decimal(10,2)`、`itemsUnit: int(1)`、`svgWidth: decimal(10,2)`、`svgHeight: decimal(10,2)`、`svgImage: longtext nullable`、`itemsUsePrice: decimal(16,2) nullable`、`expirationDate: int(4)`、`sorting: int(11)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_items_goods_log

`rowId: int(11)`、`id: varchar(255)`、`logId: varchar(255)`、`itemsId: varchar(255)`、`userAccount: varchar(255) nullable`、`itemsUsePrice: decimal(16,2) nullable`、`logExp: int(11) nullable`、`receiveOrUse: int(11) nullable`、`regist: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_level_config

`rowId: int(11)`、`id: varchar(255)`、`configId: varchar(255)`、`levelName: varchar(255)`、`fullName: varchar(255) nullable`、`levelType: int(1)`、`icon: varchar(255) nullable`、`min: int(11)`、`max: int(11)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_level_score_detail

`rowId: int(11)`、`id: varchar(255)`、`logId: varchar(255)`、`userAccount: varchar(255)`、`levelType: int(1)`、`operateType: int(1)`、`number: int(11)`、`balance: int(11)`、`remarks: longtext nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_like_log

`rowId: int(11)`、`id: varchar(255)`、`likeId: varchar(255)`、`relationId: varchar(255)`、`userAccount: varchar(255) nullable`、`typeId: int(2)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_order

`rowId: int(11)`、`id: varchar(255)`、`orderId: varchar(255)`、`tableId: varchar(255) nullable`、`scheduledTime: datetime(3)`、`totalSeatNum: int(2)`、`attribute: int(2)`、`orderType: int(2)`、`planAAPeopleNumber: int(2)`、`actualAAPeopleNumber: int(2)`、`createOrderTime: datetime(3)`、`userAccount: varchar(255)`、`operateUserId: varchar(255) nullable`、`receivableAmount: decimal(10,2)`、`actualAmount: decimal(10,2)`、`discountTotalAmount: decimal(8,2)`、`agentCommissionAmount: decimal(8,2)`、`orderStatus: int(2)`、`isOver: int(1)`、`isSex: int(1)`、`minBoyBeauty: int(3)`、`minGirlBeauty: int(3)`、`minAge: int(3)`、`maxAge: int(3)`、`useCoupon: int(1)`、`useCoin: int(1)`、`useDiamond: int(1)`、`useCash: int(1)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_order_detail

`rowId: int(11)`、`id: varchar(255)`、`detailId: varchar(255)`、`orderId: varchar(255)`、`standOrderId: varchar(255) nullable`、`goodsId: varchar(255)`、`goodsOriginalPrice: decimal(10,2)`、`goodsDiscountedPrice: decimal(10,2)`、`goodsNum: int(4)`、`goodsTotalOriPrice: decimal(10,2)`、`goodsTotalDisPrice: decimal(10,2)`、`goodsStatus: int(1)`、`userAccount: varchar(255) nullable`、`statusDate: datetime(3) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_order_member

`rowId: int(11)`、`id: varchar(255)`、`memberId: varchar(255)`、`orderId: varchar(255)`、`userAccount: varchar(255)`、`age: int(3)`、`gender: int(2)`、`avatarUrl: varchar(255) nullable`、`payablePrice: decimal(10,2)`、`preferentialPrice: decimal(10,2)`、`actualPrice: decimal(10,2)`、`memberStatus: int(2)`、`enterTime: datetime(3) nullable`、`leaveTime: datetime(3) nullable`、`payStatus: int(2)`、`failureTime: datetime(3)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_order_temp

`rowId: int(11)`、`id: varchar(255)`、`tempId: varchar(255)`、`userAccount: varchar(255) nullable`、`reserveDate: datetime(3)`、`tableId: varchar(255)`、`goodsId: varchar(255)`、`actualAAPeopleNumber: int(2)`、`orderType: int(1)`、`orderStatus: int(1)`、`isHost: int(1)`、`isSex: int(1)`、`useCoupon: int(1)`、`useCoin: int(1)`、`typeId: varchar(255)`、`subTypeId: varchar(255) nullable`、`otherUserAccount: varchar(255)`、`balancePayAmount: decimal(10,2)`、`goldCoinPayAmount: int(10)`、`couponId: varchar(255) nullable`、`couponDiscountAmount: decimal(10,2)`、`cashPayAmount: decimal(10,2)`、`modeId: varchar(255)`、`giftCouponId: varchar(255) nullable`、`giftGoldCoinNum: varchar(255) nullable`、`giftExperienceNum: varchar(255) nullable`、`giftCreditScoreNum: varchar(255) nullable`、`minBoyBeauty: int(3)`、`minGirlBeauty: int(3)`、`minAge: int(3)`、`maxAge: int(3)`、`tempStatus: int(1)`、`relationId: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_prop

`rowId: int(11)`、`id: varchar(255)`、`propId: varchar(255)`、`userAccount: varchar(255)`、`itemId: varchar(255) nullable`、`number: int(10)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_prop_function_item

`rowId: int(11)`、`id: varchar(255)`、`itemId: varchar(255)`、`propName: varchar(255)`、`imageUrl: varchar(255) nullable`、`describe: longtext nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_push_log

`rowId: int(11)`、`id: varchar(255)`、`logId: varchar(255)`、`fromUserAccount: varchar(255)`、`messageId: varchar(255)`、`toUserAccount: longtext`、`content: longtext nullable`、`remarks: longtext nullable`、`pushStaus: varchar(255)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_question_answer

`rowId: int(11)`、`id: varchar(255)`、`answerId: varchar(255)`、`questionId: varchar(255)`、`userAccount: varchar(255)`、`content: longtext`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_question_options

`rowId: int(11)`、`id: varchar(255)`、`optionId: varchar(255)`、`questionId: varchar(255)`、`content: varchar(255)`、`type: int(1)`、`sort: int(3)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_questionnaire

`rowId: int(11)`、`id: varchar(255)`、`questionnaireId: varchar(255)`、`title: varchar(255)`、`description: longtext`、`status: int(1)`、`startDate: datetime(3)`、`endDate: datetime(3)`、`createdUserAccount: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_questions

`rowId: int(11)`、`id: varchar(255)`、`questionId: varchar(255)`、`questionnaireId: varchar(255)`、`questionTitle: varchar(255)`、`questionType: int(1)`、`sort: int(3)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_recharge_config

`rowId: int(11)`、`id: varchar(255)`、`configId: varchar(255)`、`rechargeMinMoney: decimal(10,2)`、`rechargeMaxMoney: decimal(10,2)`、`giftMoney: decimal(10,2)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_recharge_details

`rowId: int(11)`、`id: varchar(255)`、`detailsId: varchar(255)`、`walletId: varchar(255)`、`userAccount: varchar(255) nullable`、`amount: decimal(10,2)`、`balance: decimal(10,2)`、`paymentChannels: varchar(255) nullable`、`outTradeNo: varchar(255) nullable`、`tradeNo: varchar(255) nullable`、`detailsRemarks: longtext nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_refund_transaction

`rowId: int(11)`、`id: varchar(255)`、`refundId: varchar(255)`、`standOrderId: varchar(255)`、`fromTransactionId: varchar(255)`、`outTradeNo: varchar(255) nullable`、`outRefundNo: varchar(255)`、`refundFee: decimal(10,2)`、`refundStatus: int(2)`、`requestDate: datetime(3)`、`operateUserAccount: varchar(255)`、`needPayTotalAmount: decimal(10,2)`、`balanceAmount: decimal(10,2)`、`cashAmount: decimal(10,2)`、`requestParameters: longtext nullable`、`notifyDate: datetime(3) nullable`、`transactionId: varchar(255) nullable`、`wxRefundId: varchar(255) nullable`、`totalFee: decimal(16,2) nullable`、`settlementRefundFee: decimal(16,2) nullable`、`refundRecvAccout: varchar(255) nullable`、`refundAccount: varchar(255) nullable`、`refundRequestSource: varchar(255) nullable`、`cashRefundFee: decimal(16,2) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_remark_detail

`rowId: int(11)`、`id: varchar(255)`、`remarkId: varchar(255)`、`userAccount: varchar(255)`、`content: varchar(1000) nullable`、`registerId: varchar(255)`、`remarkStaus: int(1)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_rule_note

`rowId: int(11)`、`id: varchar(255)`、`noteId: varchar(255)`、`noteTitle: varchar(255)`、`content: longtext nullable`、`registerId: varchar(255)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_shop_thing

`rowId: int(11)`、`id: varchar(255)`、`thingId: varchar(255)`、`thingName: varchar(255)`、`classifyId: varchar(255)`、`thingDescribe: varchar(255) nullable`、`thingImg: varchar(255) nullable`、`thingStatus: int(1)`、`lastCheckData: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_shop_thing_check_log

`rowId: int(11)`、`id: varchar(255)`、`logId: varchar(255)`、`thingId: varchar(255)`、`classifyId: varchar(255)`、`checkStatus: int(1)`、`checkDescribe: longtext nullable`、`checkImgs: longtext nullable`、`userAccount: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_shop_thing_classify

`rowId: int(11)`、`id: varchar(255)`、`classifyId: varchar(255)`、`classifyName: varchar(255)`、`classifyDescribe: varchar(255) nullable`、`classifyType: int(1)`、`deep: int(2)`、`sort: int(4)`、`parentId: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_sign_qrcode

`rowId: int(11)`、`id: varchar(255)`、`codeId: varchar(255)`、`qrcodeSign: varchar(255)`、`goldCoinNum: int(11)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_stand_order

`rowId: int(11)`、`id: varchar(255)`、`standOrderId: varchar(255)`、`typeId: varchar(255)`、`subTypeId: varchar(255)`、`orderId: varchar(255)`、`subOrderId: varchar(255) nullable`、`userAccount: varchar(255)`、`otherUserAccount: varchar(255)`、`payableAmount: decimal(10,2)`、`discountAmount: decimal(10,2)`、`payAmount: decimal(10,2)`、`balancePayAmount: decimal(10,2)`、`goldCoinPayAmount: decimal(10,2)`、`couponId: varchar(255) nullable`、`couponDiscountAmount: decimal(10,2)`、`cashPayAmount: decimal(10,2)`、`cashPayMode: varchar(255) nullable`、`giftCouponId: varchar(255) nullable`、`giftGoldCoinNum: int(2)`、`giftExperienceNum: int(2)`、`giftCreditScoreNum: int(2)`、`payStatus: int(2)`、`payTime: datetime(3) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_stand_order_type

`rowId: int(11)`、`id: varchar(255)`、`typeId: varchar(255)`、`typeName: varchar(255)`、`deep: int(2)`、`parentId: varchar(255) nullable`、`sorting: int(4)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_stored_items

`rowId: int(11)`、`id: varchar(255)`、`storedId: varchar(255)`、`userAccount: varchar(255)`、`otherUserAccount: varchar(255)`、`itemsId: varchar(255)`、`itemsType: int(2)`、`income: int(11)`、`expense: int(11)`、`standOrderId: varchar(255) nullable`、`effectiveTime: datetime(3) nullable`、`storedType: int(1)`、`storedStatus: int(2)`、`storedProperty: int(1)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_stored_items_log

`rowId: int(11)`、`id: varchar(255)`、`logId: varchar(255)`、`userAccount: varchar(255)`、`otherUserAccount: varchar(255)`、`itemsId: varchar(255)`、`income: int(11)`、`expense: int(11)`、`storedId: varchar(255) nullable`、`storedProperty: int(1)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_stored_wine

`rowId: int(11)`、`id: varchar(255)`、`storedId: varchar(255)`、`userAccount: varchar(255)`、`goodsId: varchar(255)`、`number: int(2)`、`capacity: decimal(8,2)`、`orderId: varchar(255)`、`storedTime: datetime(3) nullable`、`effectiveTime: datetime(3) nullable`、`extractTime: datetime(3) nullable`、`storedStatus: int(2)`、`locationId: varchar(255)`、`storedUserAccount: varchar(255)`、`extractUserAccount: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`、`isRead: int(1)`

### k_subject

`rowId: int(11)`、`id: varchar(255)`、`subjectId: varchar(255)`、`subjectTitle: varchar(255)`、`publishNum: int(10)`、`visitNum: int(10)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_system_messages

`rowId: int(11)`、`id: varchar(255)`、`messageId: varchar(255)`、`userAccount: varchar(255)`、`sysMessage: varchar(255) nullable`、`content: longtext nullable`、`messageStaus: int(1)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_table

`rowId: int(11)`、`id: varchar(255)`、`tableId: varchar(255)`、`name: varchar(255)`、`describe: longtext nullable`、`image: varchar(255) nullable`、`type: int(1)`、`seatNum: int(2)`、`status: int(1)`、`minConsumption: decimal(10,2)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`、`minBeauty: int(3)`、`maxAge: int(3)`

### k_thali

`rowId: int(11)`、`id: varchar(255)`、`thaliId: varchar(255)`、`thaliTitle: varchar(255)`、`thaliContent: longtext`、`image: varchar(255) nullable`、`originalPrice: decimal(10,2)`、`discountPrice: decimal(10,2)`、`remarks: longtext nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_ticket_records

`rowId: int(11)`、`id: varchar(255)`、`recordsId: varchar(255)`、`userAccount: varchar(255)`、`memberId: varchar(255)`、`ticketStatus: int(1)`、`registerId: varchar(255)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_transaction

`rowId: int(11)`、`id: varchar(255)`、`transactionId: varchar(255)`、`standOrderId: varchar(255)`、`userAccount: varchar(255)`、`outTradeNo: varchar(255) nullable`、`tradeNo: varchar(255) nullable`、`chargeAmount: decimal(10,2)`、`discountableAmount: decimal(10,2)`、`paymetAmount: decimal(10,2)`、`paidAmount: decimal(10,2)`、`settleAmount: decimal(10,2)`、`feeRate: decimal(10,2)`、`feeAmount: decimal(10,2)`、`commissionAmount: decimal(10,2)`、`proOrderJson: longtext nullable`、`payChannel: varchar(255) nullable`、`modeId: varchar(255) nullable`、`linkPID: varchar(255) nullable`、`notifyStatus: int(2)`、`orderType: int(2)`、`notifyType: int(2)`、`notifyUrl: varchar(255) nullable`、`successUrl: varchar(255) nullable`、`settleStatus: int(2)`、`requestDateTime: datetime(3)`、`confirmDateTime: datetime(3) nullable`、`paymentDateTime: datetime(3) nullable`、`orderRemarks: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_transaction_notify

`rowId: int(11)`、`id: varchar(255)`、`notifyId: varchar(255)`、`notifyResult: varchar(255)`、`outTradeNo: varchar(255)`、`notifyContent: longtext nullable`、`payChannel: varchar(255) nullable`、`notifyType: int(2)`、`companyUser: varchar(255) nullable`、`typeId: int(2)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_tweets

`rowId: int(11)`、`id: varchar(255)`、`tweetsId: varchar(255)`、`title: varchar(255)`、`content: longtext nullable`、`src: varchar(255) nullable`、`visits: int(10)`、`like: int(10)`、`url: varchar(255) nullable`、`operateUserAccount: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_tweets_log

`rowId: int(11)`、`id: varchar(255)`、`logId: varchar(255)`、`tweetsId: varchar(255)`、`userAccount: varchar(255) nullable`、`typeId: int(2)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_user

`rowId: int(11)`、`id: varchar(255)`、`userAccount: varchar(255)`、`userName: varchar(255)`、`userNick: varchar(255) nullable`、`userSalt: varchar(255)`、`password: varchar(255)`、`userMobile: varchar(255) nullable`、`userStatus: int(1)`、`userIDCard: varchar(255)`、`userIDCardUrl: varchar(255) nullable`、`sign: longtext nullable`、`gender: int(1)`、`birthday: datetime(3) nullable`、`avatarUrl: varchar(255) nullable`、`appearanceScore: int(4) nullable`、`vipLevel: int(11)`、`creditLevel: int(11)`、`facialAuthenticationStatus: int(1)`、`faceQueryCode: varchar(255) nullable`、`invitationCode: varchar(255) nullable`、`invitationUserAccount: varchar(255) nullable`、`dressingStyle: longtext nullable`、`musicStyle: longtext nullable`、`wineStyle: longtext nullable`、`consumptionAbility: varchar(255) nullable`、`maritalStatus: int(1)`、`isAuth: int(1)`、`profession: varchar(255) nullable`、`wxOpenId: varchar(255) nullable`、`wsStatus: int(1)`、`clientType: varchar(255) nullable`、`versionNo: varchar(255) nullable`、`registrationId: varchar(255) nullable`、`domicile: varchar(255) nullable`、`ipAddr: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`、`bgImage: varchar(255) nullable`

### k_user_comment

`rowId: int(11)`、`id: varchar(255)`、`commentId: varchar(255)`、`userAccount: varchar(255)`、`worksId: varchar(255)`、`commentType: int(1)`、`content: longtext nullable`、`aiteUserAccount: longtext nullable`、`parentId: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_user_comment_image

`rowId: int(11)`、`id: varchar(255)`、`imageId: varchar(255)`、`userAccount: varchar(255)`、`commentId: varchar(255)`、`fromAddr: varchar(255) nullable`、`fileWidth: int(6)`、`fileHeight: int(6)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_user_examine_images

`rowId: int(11)`、`id: varchar(255)`、`imageId: varchar(255)`、`userAccount: varchar(255)`、`imageUrl: varchar(255)`、`imageType: int(1)`、`beauty: int(3)`、`age: int(3)`、`gender: int(1)`、`requestId: varchar(255) nullable`、`operateuserAccount: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_user_examine_type

`rowId: int(11)`、`id: varchar(255)`、`typeId: varchar(255)`、`name: varchar(255)`、`categoryId: int(1)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_user_follow

`rowId: int(11)`、`id: varchar(255)`、`followId: varchar(255)`、`userAccount: varchar(255)`、`followList: longtext nullable`、`likeNum: int(10)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_user_info

`rowId: int(11)`、`id: varchar(255)`、`infoId: varchar(255)`、`userAccount: varchar(255)`、`isOpen: int(1)`、`stature: decimal(10,2)`、`weight: decimal(10,2)`、`type: varchar(255) nullable`、`educational: varchar(255) nullable`、`schoolName: varchar(255) nullable`、`forte: varchar(255) nullable`、`hobby: varchar(255) nullable`、`career: varchar(255) nullable`、`workUnit: varchar(255) nullable`、`incomeRange: varchar(255) nullable`、`hasHouse: int(1)`、`hasCar: int(1)`、`hasLiabilities: int(1)`、`nowCity: varchar(255) nullable`、`hasSmoking: int(1)`、`hasDrinking: int(1)`、`isCpc: int(1)`、`favoriteSongs: varchar(255) nullable`、`favoriteBooks: varchar(255) nullable`、`geneticHistory: varchar(255) nullable`、`loveFrequency: int(2)`、`longSingle: varchar(255) nullable`、`hasSibling: int(1)`、`homeRanking: int(1)`、`hasOriginFamily: int(1)`、`fatherCareer: varchar(255) nullable`、`motherCareer: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_user_like_praise_collect

`rowId: int(11)`、`id: varchar(255)`、`recordId: varchar(255)`、`userAccount: varchar(255)`、`likeWorksId: longtext nullable`、`collectWorksId: longtext nullable`、`isOpenLike: int(1)`、`isOpenCollect: int(1)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_user_relation

`rowId: int(11)`、`id: varchar(255)`、`relationId: varchar(255)`、`userAccount: varchar(255)`、`agenyType: int(1)`、`parentId: varchar(255)`、`agencyStatus: int(1)`、`commissionRate: decimal(10,2)`、`serviceRate: decimal(10,2)`、`ktvRate: decimal(10,2)`、`dinnerRate: decimal(10,2)`、`standRate: decimal(10,2)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_user_setting

`rowId: int(11)`、`id: varchar(255)`、`settingId: varchar(255)`、`userAccount: varchar(255)`、`isMatch: int(1)`、`newFriends: int(1)`、`hopeGender: int(1)`、`hopeStatus: int(1)`、`ageRange: varchar(255) nullable`、`beautyValue: varchar(255) nullable`、`hopeType: varchar(255) nullable`、`hopeStature: varchar(255) nullable`、`hopeWeight: varchar(255) nullable`、`hopeeDucational: varchar(255) nullable`、`hopeIncomeRange: varchar(255) nullable`、`hasHouse: int(1)`、`hasCar: int(1)`、`hasLiabilities: int(1)`、`hopeCity: varchar(255) nullable`、`hasSmoking: int(1)`、`hasDrinking: int(1)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_user_setup

`rowId: int(11)`、`id: varchar(255)`、`setupId: varchar(255)`、`conversationsId: varchar(255)`、`userAccount: varchar(255)`、`otherUserAccount: varchar(255)`、`userRemark: varchar(255) nullable`、`otherMobile: varchar(255) nullable`、`description: varchar(1000) nullable`、`setupFriendCircle: int(1)`、`closeFriendCircle: int(1)`、`noSeeFriendCircle: int(1)`、`isTop: int(1)`、`noMessage: int(1)`、`saveAddressBook: int(1)`、`isBackground: varchar(255) nullable`、`isUserNick: int(1)`、`userRelation: int(2)`、`groupName: varchar(255) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_user_works

`rowId: int(11)`、`id: varchar(255)`、`worksId: varchar(255)`、`userAccount: varchar(255)`、`fromIp: varchar(255) nullable`、`fromAddr: varchar(255) nullable`、`typeId: int(1)`、`worksTitle: varchar(255) nullable`、`contentType: int(1)`、`contentText: longtext nullable`、`aiteUserAccount: longtext nullable`、`tagList: longtext nullable`、`canLike: int(1)`、`canComment: int(1)`、`canForward: int(1)`、`canDownload: int(1)`、`isOpen: int(1)`、`latitude: decimal(20,15)`、`longitude: decimal(20,15)`、`address: varchar(255) nullable`、`isTop: int(1)`、`clickCount: int(11)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_user_works_files

`rowId: int(11)`、`id: varchar(255)`、`fileId: varchar(255)`、`userAccount: varchar(255)`、`worksId: varchar(255)`、`contentType: int(1)`、`fileUrl: varchar(255) nullable`、`fileWidth: int(6)`、`fileHeight: int(6)`、`poster: varchar(255) nullable`、`fileSize: int(11)`、`duration: decimal(10,2) nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_virtual_goods

`rowId: int(11)`、`id: varchar(255)`、`vgId: varchar(255)`、`vgName: varchar(255)`、`vgFullName: varchar(255) nullable`、`vgHot: int(11)`、`classificationId: varchar(255)`、`iconImage: varchar(500) nullable`、`appImage: varchar(500) nullable`、`vgImage: varchar(255) nullable`、`describe: longtext nullable`、`vgStatus: int(1)`、`price: int(11)`、`vgUnit: int(1)`、`svgWidth: decimal(10,2)`、`svgHeight: decimal(10,2)`、`svgImage: longtext nullable`、`sorting: int(11)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_virtual_goods_log

`rowId: int(11)`、`id: varchar(255)`、`logId: varchar(255)`、`userAccount: varchar(255)`、`counterparty: varchar(255)`、`conversationsId: varchar(255)`、`vgId: varchar(255)`、`vgNumber: int(10)`、`vgPrice: int(10)`、`income: int(10)`、`expense: int(10)`、`vgType: int(1)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_wallet

`rowId: int(11)`、`id: varchar(255)`、`walletId: varchar(255)`、`userAccount: varchar(255)`、`walletStatus: int(1)`、`balance: decimal(10,2)`、`walletType: int(1)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_warehouse

`rowId: int(11)`、`id: varchar(255)`、`warehouseId: varchar(255)`、`warehouseType: int(2)`、`batchId: varchar(255)`、`goodsBathId: varchar(255)`、`siteId: varchar(255)`、`registId: varchar(255) nullable`、`warehouseManageId: varchar(255) nullable`、`goodsId: varchar(255)`、`propertyId: varchar(255) nullable`、`goodsSpecs: varchar(255) nullable`、`goodsCost: decimal(10,2)`、`goodsPrice: decimal(10,2)`、`entryNumber: decimal(10,2)`、`outNumber: decimal(10,2)`、`warehouseDesc: text nullable`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`

### k_withdrawal

`rowId: int(11)`、`id: varchar(255)`、`withdrawalId: varchar(255)`、`walletId: varchar(255)`、`detailsId: varchar(255)`、`money: decimal(10,2)`、`withdrawalStatus: int(2)`、`withdrawalDate: datetime(3)`、`completeDate: datetime(3) nullable`、`remarks: longtext nullable`、`cardId: varchar(255) nullable`、`cardNumber: varchar(255) nullable`、`bankName: varchar(255) nullable`、`bankFullName: varchar(255) nullable`、`userName: varchar(255) nullable`、`userMobile: varchar(255)`、`createdDate: datetime(3)`、`updatedDate: datetime(3)`、`indexed: tinyint(1)`、`deleted: tinyint(1)`
