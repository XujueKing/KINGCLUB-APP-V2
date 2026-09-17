# 数据、库存与账务设计提案

状态：Model In Review。**用户明确暂不导入旧数据库数据**；本文不是建表脚本或迁移执行计划。对象名称为概念名，尚未分配正式表、接口或 migration 编号。

## 1. 旧对象去向

| 旧对象组 | 确认语义 | 目标概念 / 处理建议 |
|---|---|---|
| k_goods、k_goods_classification | 商品、分类、单品/套餐、状态与售价 | Product / Category；增加渠道和版本，保留来源映射方案但不导数据 |
| k_goods_detail | 套餐组成及组成数量 | BundleComponent；不是 SKU 属性，不当销售明细 |
| k_goods_property | 条码属性、规格、基本单位、保质期 | ProductVariant / UnitRule；首版单规格可隐藏变体界面 |
| 无独立完整 K_ 对应 | 受控供应商、易耗品领用、备用金、调酒用量 | Supplier、MaterialIssue、CashTransfer、BarUsage；manufacturerId/companyId 不能直接当已验证供应商名录 |
| k_batch、k_goods_batch | 采购人员、批次、成本及计划/批准/发货量 | Purchase / PurchaseLine / ReceiptBatch；采购、实际收货和付款分开 |
| k_warehouse | 入库、出库、盘点登记 | InventoryMovement；不要映射成仓库主档 |
| k_goods_warehouse_location | 仓位主档 | StockLocation；默认一处，旧快照为空不能虚构历史仓位 |
| k_shop_thing* | 店内物品及巡检 | 单独设备/物品检查候选；不是本期销售库存主表 |
| k_order、k_order_member、k_table | 开台/预约、参与人、桌台 | DiningSession + SalesOrder 引用；已有预约域不整体搬入 commerce |
| k_order_detail | 销售商品行和上菜状态 | SalesOrderLine + Fulfillment；原价格/数量快照不回写商品现价 |
| k_stand_order | 一次业务付款的标准单 | SalesOrder / PaymentAllocation 的旧来源，不能简单一对一改名 |
| k_transaction、k_transaction_notify、k_refund_transaction | 支付尝试、回调日志、退款 | PaymentAttempt / PaymentEvent / Refund；查询、取消、回调归一处理 |
| k_wallet、k_balance_details | 多类型钱包及收支明细 | AssetAccount / AssetEntry；余额投影从受控流水推导 |
| k_goldcoin_detail、k_diamond_detail | 数量型资产流水 | 独立 assetType / precision；不得与人民币分相加 |
| k_bill_detail | 用户账单展示及业务引用 | 展示投影/历史参考；不是财务凭证事实源 |
| k_user_relation、k_division、k_commission_log、k_withdrawal | 代理关联、分配/佣金/提现相关 | Commission / Withdrawal；待核清最终结算源，不自动照搬百分比或提现期 |
| k_items_goods、k_stored_items*、k_stored_wine、k_drinks_access_log | 权益目录、个人券/存酒及流转 | 复用/扩展已独立接入的 storage 领域；与销售商品库存分开 |
| 无旧完整对应 | 交班、配送/自提、财务总账、链上商店 | 新设计，不能伪称旧功能迁移已覆盖 |
| k_subject | 社交话题 | 不迁为会计科目 |

## 2. 最小关系模型

以下是概念实体，可以按实现评审合并没有独立生命周期的结构；不是要求立即创建同数量数据表。

| 领域 | 概念实体与必要关系 | 关键约束 |
|---|---|---|
| 商品 | Supplier、Product、Category、Variant、BundleComponent/Recipe | 员工只选启用 ID；维护单独授权；销售/原料/易耗分类；组成不能循环；单位明确；版本不改历史 |
| 采购 | Purchase → PurchaseLine → ReceiptBatch；采购付款关联 CashEntry | 部分收货、部分付款可追踪；同一收货业务键不得重复增加库存 |
| 库存 | StockLocation、BatchBalance、InventoryReservation、InventoryMovement、Stocktake | 固定锁序；库存和预留非负；批次出库与订单行唯一关联；调整必须有原因 |
| 吧台/领用 | StockTransfer、MaterialIssue、BarUsage | 调拨双边一致；开瓶单位按档案；订单出库与用酒记录关联，实际差异不重复扣减 |
| 销售 | DiningSession、SeatingAssignment、SalesOrder → SalesOrderLine、QuoteSnapshot | 到店订单绑定本次开台/入座会员，非到店订单不强加桌号；actor/consumer/payer 分开；换桌有历史 |
| 支付 | PaymentAttempt、PaymentAllocation、PaymentEvent、Refund | 一个订单可有不同支付组成；通道交易/事件和业务幂等键唯一；累计退款不能超原实收/可退组成 |
| 交付 | Fulfillment、PickupCredential、DeliveryInfo | 到店/自提/配送/链上使用可判别类型，不用大量无关必填字段；核销只生效一次 |
| 经营账 | CashAccount、CashTransfer、CashEntry、Expense、Shift | 备用金领用/归还为调拨；领取人与操作人分开；采购/销售/费用分开；每条有来源 |
| 会员资产 | AssetAccount、AssetHold、AssetEntry | 现金/赠送/授信/佣金/金币/券等规则独立；资产流水不随用户删除账单而删除 |
| 财务账 | Account、AccountingPeriod、Voucher → VoucherLine、PostingRuleVersion | 分录借贷平衡；已过账不可原地改；同一业务事件/模板版本不得重复过账；期间关闭后阻止补写 |
| 链上交易 | ChainAssetListing、ChainOrderIntent、ChainSettlement | chain/asset/intent/tx/receipt 显式绑定；不能单靠 txHash 关联订单；幂等并核实所有权 |
| 共用 | IdempotencyRecord、AuditEvent、Outbox/任务记录 | 单据/账务与外部待办在同事务；任务至少可恢复重试；日志不存敏感原文 |
| 收银机 | CounterTerminal、OperatorGrant、PrintJob | 终端授权与员工操作身份分开；权限不绕过登录冻结；打印关联单据版本/票种，不产生新交易 |

不把整个系统做成事件溯源平台；只有库存、资产与财务已确认流水采用追加/冲正，其他草稿和商品资料可正常受版本控制地编辑。

## 3. 库存计算与状态

默认库存维度：门店 + 仓位 + SKU + 批次 + 基本单位。建议按先入先出自动分配批次；人工日常操作只选商品和数量。

- 账面未售数量 = 入库 + 可再售退回 + 盘盈 − 销售出库 − 报损/其他出库 − 盘亏。
- 可售数量 = 账面未售数量 − 未付款有效预留数量。
- 已付待交付数量 = 已销售出库但尚未上桌/取走/发货的数量；不可再次销售。
- 在盘点相同位置/口径时，预期实物 = 账面未售数量 + 该位置已付待交付数量。若待交付已移到独立备货区，盘点按位置分别计算，不能重复加。

预留状态：`active → consumed / released`。付款确认消耗预留并形成销售出库；发货/上菜完成只减少待交付，不再扣一次账面未售。退货只有确认回到可售位置且质量可售才回库；退款本身不代表实物已返回。

单品可售数受所有销售渠道共享约束；套餐可售份数由每个组成的可售量除以配方数量后向下取整，取最小值。套餐数量只展示计算结果，不另保留一份能脱离组成库存增长的数量。

每日盘点保存开始快照、每项计数时点/版本、实点数、期间业务变动和调整原因。若计数与出入库并发无法确定顺序，要求重数冲突项；不靠“最后保存的人赢”覆盖实时库存。成本缺失时提示补成本，利润不能悄悄按零成本展示。

### 吧台与易耗品

酒水/调酒原料/易耗品使用同一个受控物料基础，以 category 与销售资格区分。瓶装酒的容量、箱瓶换算、最小计量精度由管理人员设置；开瓶记录原批次和剩余量，不能凭员工自由写名称制造另一份库存。

调酒用量账保存 usageId、来源订单行/出库行、recipeVersion、酒款/批次、理论量、实际量、差异、用途、操作人/时间。付款自动扣过配方用量后，吧台确认同一用量只补充事实，不再扣一次；差异确认追加一条调整。非订单用量按试饮/训练/损耗等原因独立扣减与计成本。

易耗用品采购/入库/领用/损耗各有单据。建议领用或损耗时结转相应费用，采购付款仅记资金流；最终会计模板另确认，任何方案都不能在采购和领用时重复费用化。

备用金 cashTransfer 关联 sourceAccount、barCashAccount、amount、recipient、actor、交接时间和班次；钱箱不是员工个人资产。领入/归还只在两个经营资金账户间移动，实际支出凭原单分类记费用。

### 桌台、会员和打印

现有 k_order_member 有 userAccount、orderId、memberStatus、enterTime/leaveTime，k_order 关联 tableId；这是旧会员入座链的来源，不能简单拿 k_table.status 代替成员历史。新设计优先对接现有会员/预约域，以开台和 seatingAssignment 的有效时间确定到店订单归属。消费会员集合、下单人、付款会员、收银操作人分别记录。

换桌追加转移记录，未来订单使用新位置；已结订单保留原桌次。打印任务绑定订单/开台的已确认快照、模板版本、打印终端、票种、操作员工和补打次数。打印失败不回滚支付或库存，补打不生成新销售。详细看板字段及小票内容见终端设计。

## 4. 订单、支付、履约分开

| 对象 | 建议状态 | 含义 |
|---|---|---|
| 销售订单 | draft / awaitingPayment / confirmed / cancelled / closed | 成立/取消状态，不承担全部支付与配送细节 |
| 支付尝试 | created / pending / succeeded / failed / closed / unknown | 网络超时属于 unknown，不能当 failed；以渠道验证结果转换 |
| 退款 | requested / processing / succeeded / failed / unknown | 支持部分退款并绑定原支付组成；退款失败不提前恢复权益/记现金已退 |
| 履约 | awaitingPayment / ready / partiallyFulfilled / fulfilled / cancelled | 到店上菜、自提/配送按类型完成；退货是关联动作，不把已交付历史抹掉 |
| 链上结算 | awaitingSignature / submitted / confirming / settled / failed / reviewRequired | submitted 不等于 settled；签名拒绝不伪造链交易 |
| 采购 | draft / ordered / partiallyReceived / received / cancelled | 收货状态与付款状态正交，支持一张采购多批入库 |

默认顾客先付款，用户已经明确选择，不能再将先消费后结账作为默认。现金开单可由收银员确认实际收款触发同一个付款完成用例。

## 5. 自动记账与利润

三个视图共享业务来源：

1. **经营账**给老板看真实收付和经营表现。
2. **会员账**给会员/员工看储值、赠送、积分、券、佣金等余额变化。
3. **财务账**给老板或会计查看自动凭证、科目、总账和报表。

采购收货确认存货及已付/应付关系；采购付款改变资金/应付，不再次增加库存。销售付款确认收款和待履约关系，直接买单付款成功或加餐 AA 全部人数付齐成单时完成销售出库；基础入局券先记权益，员工开局备酒时整桌套餐出库；商品尚未实际交付时保留待交付数量/成本。履约确认时按适用模板结转销售与成本，不因为已出销售库存就强行把所有未履约订单算作财务已确认收入。

经营面板可显示已付款订单的预计毛利，但必须与已完成交付的确认利润分开；老板看到“预计/已确认”和缺少成本待办，不用选择借贷科目。到店已付款随后上菜、自提取货、配送签收/约定完成、链上资产最终交割的确认时点在产品规则中冻结。

常用自动模板：采购收货、采购付款、销售收款、销售履约及成本、采购退回、销售退款/退货、日常费用、会员充值与消费、佣金计提/结算、现金差异、库存盘盈盘亏。每份凭证保留来源单据、金额/数量、期间和模板版本。

进货金额、销售出库成本、日常费用不得重复计入利润。会员充值是资金/会员负债变化，不直接算销售；会员使用储值消费时才与相应商品销售关联。赠送金、金币、券和佣金按已确认政策生成独立记录，不能简单当人民币现金收入。

通用的业务展示口径：

`销售净额 = 已确认销售 − 销售折让/退款调整`

`毛利 = 销售净额 − 对应已售批次成本`

`经营利润 = 毛利 − 经营费用 +/− 适用库存/经营调整`

税费、折旧、链上资产估值/兑换差额、收入确认政策和法定报表模板仍需确定；本轮不设任意税率、不宣称预设报表已经法定合规。完整财务能力保留，未完成初始设置时禁止展示为“已正式结账”。

## 6. 字段规则

- 保留来源业务 ID 的映射设计，不把旧 rowId 作为新业务身份；现阶段不导入映射数据。
- 新建对象遵循 CCSOP camelCase、rowId/createdDate/updatedDate、双语 COMMENT 和目录登记；此处概念名不是最终物理命名。
- 金额以币种 + 最小单位整数/精确 decimal 表达，跨 API 对超安全整数范围用字符串；数量及批次单价使用规定小数精度和舍入规则。金币、人民币、链资产最小单位分开。
- 多批次合计分摊产生的舍入尾差按确定规则分配到最后明细/专用差额记录，退款按原分摊快照，不能重新按当前价格计算。
- createdDate 是记录时间，另有 businessDate、occurredAt、paidAt、receivedAt、fulfilledAt；营业日与时区明确，避免跨午夜失真。
- 草稿可删，已确认库存/支付/资产/财务记录用状态及冲正处理。用户账单隐藏不删除源流水。
- 地址/电话只用于配送受限保存，不出现在公开链；链上只使用必要资产标识/意图摘要，不把订单全文或个人资料上链。
- 旧未解释字段进入待核清列表，不能默认归零、取现价、抹掉软删除或复活过期券。

## 7. 数据导入明确暂停

用户已明确：**暂时不要导入，因为结构可能变化**。因此本轮没有执行数据库连接、建表、restore、ETL、种子真实数据或历史补录。旧 SQL 留在原目录，统计产物只有结构与脱敏数量。

下一阶段仍先设计新结构和合成样例。将来是否迁移历史，迁移哪些商品/库存期初/会员权益/订单，要由用户另行确定；不能因本包包含旧表映射就自动开始。

未来若获得导入授权，最低核对维度是商品/套餐引用、每批数量与成本、订单支付退款状态、每账户分类余额、待履约和预留、券有效期与归属、凭证期初及借贷平衡。只做转换不重播付款/奖励。双端并行要定义唯一写入方和回滚水位，但本轮不实施任何同步或切换。

## AA 业务补充（用户最新确认）

参见 [AA 入局、共享套餐与加餐](AA_AND_SHARED_PACKAGE.md)。点单必须提供「直接买单 / 发起 AA」。抖音、美团券自助核销或 App 购买后取得入局权益，按卡座容量和男女配比预定；预定与实际入座分别显示。基础共享套餐在员工确认开局、准备酒水时整桌出库一次，不能逐人核销重复出库。加餐 AA 由发起人设置人数，参与者先付各自份额，人数与款项付齐才成单并整单出库，未成团超时退款。此前“付款立即出库”适用于直接买单；买入局券和单人支付 AA 份额不触发整套出库。

目标模型补充：ExternalVoucherRedemption（外部核销及唯一凭据）、AdmissionEntitlement（入局权益）、TableSessionConfigSnapshot（容量/配比/套餐版本）、SessionMembership（名额/权益/入座）、SharedPackageFulfillment（整局套餐唯一出库）、AAGroup（人数/期限/金额快照）、AAParticipation（会员与份额）、ParticipantPayment/Refund（逐笔资金）。这些是概念模型，尚非批准的表名或迁移。外部核销、参与付款、成团、出库分别去重并保留来源。

## 平台化补充（用户最新确认）

[平台、多经营主体与多门店](PLATFORM_AND_STORES.md) 为本包归属与隔离规则。平台服务不同老板、不同品牌、多地区多门店；地区用于发现，经营主体用于隔离，门店用于实际经营。此前单店/一套主体模板只可解释为单个核算主体的简单默认，不能解释为全平台共用库存、钱包、收款或总账。手机、订台、AA、收银、打印及统计均须带正确范围。

## 会员存酒服务

用户已确认 [存酒/取酒与二维码核销](MEMBER_WINE_STORAGE.md)。联动现有 APP 储物柜与动态码，增加员工手机/收银机存取办理和门店权限。会员保管酒不进入可售库存，取酒不重复记销售或扣销售库存；存取事件、实际操作者、归属及二维码均可追溯。AA 余酒归属、计量、期限、代取/跨店规则列为待确认，不能自动分配给发起人。

概念扩展：StorageDepositRequest、StoragePickupRequest、CustodyBottle/Batch、CustodyEvent 与现有 StorageHolding/Pickup/Event 的映射需审查；复用既有会员和目录，不建立第二套不一致余额。请求区分待确认/已确认/取消/过期，实物保管状态与二维码状态独立；新接口用明确的取出量，内部校验余额和并发版本。暂不新增正式表或迁移编号。
