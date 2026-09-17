# 旧表、新服务已建功能与草案复用审查

2026-09-18。只读本地新服务 126 个 migration SQL、src 引用和已有功能部署记录。识别 86 个不同建表名称，详见 [源码表清单](EXISTING_TABLE_INVENTORY.md)。**本轮未连接运行中数据库查询 information_schema，不能将本地 86 表直接说成服务器现有 86 表。**

## 1. 结论与更正

用户指出已有功能已经建表是正确的。身份、资料、资产投影、储物、接口目录、审计、文件和外部回调均存在新服务结构或实现，不能按“全新业务系统”重建。

尤其更正之前按 wallet 名称搜索的不足：`033_kingclub_profile.sql:21` 已创建 `kingclubProfileAssets`，有 cashBalance DECIMAL(18,2)、goldCoin、diamond 等；`src/kingclub/profile/profile-service.ts:18,24,48` 有初始化、奖励更新和读取。它是正在使用的资产投影，不是“没有钱包表”。但以 userAccount 唯一、没有主体/币种分账和完整资金流水，亦不能直接认为已具备本期多商户余额退款账。

已有 [个人中心数据库记录](../../../profile_settings/feature_profile_center/database_review.md) 写明 033/034 已在隔离 KingClub 库部署；[储物实施记录](../../../club/feature_private_storage/2026-09-12-implementation.md) 写明 031/032 已部署。证据属于此前会话的部署记录，不是本轮远程现状复核。已有单会员存酒/券授权迁入记录也必须保留，不再次导入、不清空新库。

## 2. 旧表与新实现复用矩阵

| 旧对象/需求 | 新服务已有对象或代码 | 处理结论 |
|---|---|---|
| k_user、会员身份/个人资料 | kingclubMember、kingclubProfile、身份/登录/同意记录；018/027/033 等 | 复用当前会员 userAccount，不新建第二套会员/登录，不照搬旧用户表 |
| k_wallet、余额/金币/钻石展示 | kingclubProfileAssets；033，profile-service.ts | 保留当前资产与前端读取；补主体资金明细及投影同步方案后再决定扩表，不直接替换余额 |
| 注册赠送 | kingclubRegistrationReward；034 | 复用唯一奖励事实，不能重发注册金币，更不能当现金入账 |
| k_goods 与存酒/道具目录 | kingclubStorageProduct；031 | 已有储物商品目录可映射到销售商品；不能直接认定具备采购、售价、配方、批次能力 |
| k_stored_wine、k_stored_items | kingclubStorageHolding；031/032，storage-service.ts | 复用 holding/itemRef 和余量；补门店、订单来源/购买者资格，不能另建独立可变保管余额 |
| 取酒二维码 | kingclubStoragePickup、kingclubStorageEvent | 复用会话/版本/令牌哈希与事件幂等基础，扩门店核验；新 commandId 必须适配旧 staff requestId，不随意改现有协议 |
| 券入袋/券面抵用显示 | StorageProduct.maximumValue、holding/item 分类和历史券导入记录 | 不是从零开始；抵扣/折扣、占用、规则快照、订单消费/返券仍需检查补齐 |
| s_interface/类型/过程目录 | interface、interface_type、interface_type_relation、databaseCatalog*、databaseRoutineCatalog | 复用已有目录与超级接口执行器，正式 migration 必须登记，不能另做接口注册系统 |
| 操作审计 | platform_audit_log、MysqlAuditRepository | 已有实现；先复用通用审计，只有业务事务内的不可丢失事件确有缺口才增业务事件表 |
| 支付/第三方回调接收 | platform_external_callback_log、external-callback-repository.ts | 复用接收/队列/状态基础；不等于已有商品支付结算流水，需补业务商户映射与防重 |
| 图片/附件/通知 | platform_file_object、platform_notification_log、对应平台模块 | 复用基础设施，补业务引用和权限范围，不重建附件服务 |
| 可靠通知模式 | kingclubChatOutbox 与聊天模块 | 可参考模式，不能给 commerce 共用聊天业务表或改聊天队列；需审查通用任务边界 |
| 开台/标准支付单/渠道交易/批次/采购 | 本次 migration 建表名和 src 扫描未定位完整对应经营表 | 仍为新增候选，不能把“未定位”写成线上不存在；保留旧分层，先查实时目录再定稿 |

## 3. 对现有 35 表草案的处理

| 候选表组 | 当前处理 |
|---|---|
| supplier/product/product_unit/recipe_version/recipe_line/purchase/purchase_line | 暂留候选；product 须先关联已有 StorageProduct，明确目录是主体共享还是分店定价 |
| location/stock_batch/stock_balance/goods_receipt/goods_receipt_line/inventory_guard | 暂留经营库存候选；明确这是可售库存，不是替换现有会员保管库存 |
| activity/table_config/table_session/registration/current_registration/seat_assignment/current_seat | 暂留；会员外键映射当前独立会员，旧开台/报名语义保持；在线存在性待查 |
| sales_order/sales_line/aa_group/aa_share/payment_fact/refund_intent | 暂留但不完整；标准业务支付单、支付尝试和混合支付需结合旧过程及已有回调补齐 |
| stock_reservation/reservation_line/inventory_issue/inventory_movement/shared_package | 暂留；出库唯一来源和批次关系仍需事务验证 |
| business_command | 评估各现有幂等机制后再决定；业务命令去重不能等同传输防重放 |
| audit_event | **暂停作为确定新增表**；先评估 platform_audit_log 的业务范围、事务连接和保留期差异 |
| outbox_event | 模式候选；现有通用队列/回调接收能复用的部分不重复；不得混进聊天表 |
| storage_holding_link | **仅作为扩展方案候选**；比较给现有 holding 扩字段与关联表两方案，选择前不注册新表 |

本轮不删除候选 SQL，也不继续当作“35 张都必须新建”。在文件头加入复用审查门禁，待逐表决策再生成真正增量 migration。

## 4. 必须与新服务规范对齐

当前 `ccsop-service/AGENTS.md` 要求 camelCase、rowId、createdDate/updatedDate、表和字段中英 COMMENT、递增 migration、数据库目录登记。已有 kc_draft_* snake_case 草案**不满足正式落库规范**，只可用于关系讨论。转换必须在复用结论之后，不能直接拷贝执行。

审计代码当前通过 mysqlPool 写入，不能仅因有审计表就假定与 commerce 库存事务原子；需要事务连接传递或明确的业务事件衔接。资产表的 cashBalance 是人民币小数金额，而草案采用最小单位整数，必须显式转换与来源核对，不直接把 100 分写为 100 元。

## 5. 下一步只读现状核验

需要目标运行环境的只读结构证据：information_schema 的表/列/索引/外键、实际迁移执行记录、databaseCatalogTable 目录对照。只读结构，不读会员金额/手机号/存酒明细，不执行修复或补迁移。

本轮未取得并使用经过确认的数据库只读连接；不运行 deploy 脚本猜环境，也不从日志整段复制连接密码。若当前已登录的数据库管理界面可用，可直接按用户指定环境核对结构；核对前所有“实际服务器存在”结论按历史部署记录标注。
