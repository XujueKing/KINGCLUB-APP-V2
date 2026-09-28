# 数据盘点附件

状态：本地快照只读盘点；不是现网对账，不代表数据导入或新模型已批准。

源文件：`D:/2026-ZHUZHOU/物业信数据库/nuggets-结构+数据.sql` 与 `nuggets-仅结构.sql`。指纹见 [旧系统审计](LEGACY_AUDIT.md)。

本次解析全部 94 张 K_ 表的导出记录，共 33,997 行，解析错误 0。下表只展示与本轮相关的对象。非删除数仅表示 deleted=0，不代表有效、可售、已支付或当前仍有权益。状态分布包含软删除行，不混用作营业数字。

## 1. 表与快照数量

| 表 | 全部行 | deleted=0 | CREATE 行（仅结构 SQL） |
|---|---:|---:|---:|
| `k_goods` | 45 | 45 | 5825 |
| `k_goods_classification` | 22 | 22 | 5924 |
| `k_goods_detail` | 70 | 70 | 5949 |
| `k_goods_property` | 19 | 19 | 5976 |
| `k_batch` | 1 | 1 | 5296 |
| `k_goods_batch` | 19 | 19 | 5890 |
| `k_warehouse` | 30 | 30 | 7569 |
| `k_goods_warehouse_location` | 0 | 0 | 6013 |
| `k_goods_access_log` | 0 | 0 | 5864 |
| `k_shop_thing` | 0 | 0 | 6621 |
| `k_shop_thing_check_log` | 0 | 0 | 6645 |
| `k_shop_thing_classify` | 0 | 0 | 6669 |
| `k_table` | 16 | 16 | 6902 |
| `k_order` | 116 | 115 | 6185 |
| `k_order_detail` | 125 | 125 | 6228 |
| `k_order_member` | 181 | 179 | 6257 |
| `k_order_temp` | 58 | 58 | 6289 |
| `k_stand_order` | 242 | 240 | 6713 |
| `k_stand_order_type` | 15 | 15 | 6752 |
| `k_transaction` | 311 | 311 | 6975 |
| `k_transaction_notify` | 258 | 258 | 7019 |
| `k_refund_transaction` | 0 | 0 | 6539 |
| `k_wallet` | 2825 | 2825 | 7547 |
| `k_balance_details` | 1409 | 1074 | 5235 |
| `k_goldcoin_detail` | 2501 | 2173 | 5798 |
| `k_diamond_detail` | 665 | 339 | 5700 |
| `k_bill_detail` | 4407 | 4403 | 5320 |
| `k_commission_log` | 0 | 0 | 5383 |
| `k_division` | 374 | 374 | 5727 |
| `k_user_relation` | 342 | 342 | 7326 |
| `k_withdrawal` | 1 | 1 | 7601 |
| `k_recharge_details` | 0 | 0 | 6513 |
| `k_items_goods` | 2 | 2 | 6057 |
| `k_stored_items` | 414 | 414 | 6774 |
| `k_stored_items_log` | 1358 | 1358 | 6803 |
| `k_stored_wine` | 5 | 5 | 6828 |
| `k_drinks_access_log` | 1 | 1 | 5748 |
| `k_subject` | 2 | 2 | 6859 |

## 2. 非个人状态统计

| 表.字段 | 快照分布（含软删除） |
|---|---|
| `k_goods.goodsProperty` | 0: 33、1: 12 |
| `k_goods.goodsStatus` | 1: 45 |
| `k_warehouse.warehouseType` | 0: 30 |
| `k_order.isOver` | 0: 85、1: 31 |
| `k_order.orderType` | 1: 116 |
| `k_order_detail.goodsStatus` | 0: 101、1: 24 |
| `k_stand_order.payStatus` | 0: 23、1: 219 |
| `k_transaction.notifyStatus` | 1: 249、2: 62 |
| `k_transaction.settleStatus` | 0: 311 |
| `k_wallet.walletType` | 0: 770、1: 685、2: 685、3: 685 |
| `k_balance_details.accountType` | 0: 734、1: 671、2: 1、3: 3 |
| `k_balance_details.detailsStatus` | 1: 1409 |
| `k_bill_detail.typeId` | 0: 196、1: 1032、2: 2503、3: 664、4: 12 |

这些状态只能说明导出时记录分布。尤其 249 条待回调、全部交易 settleStatus=0 不能直接判定现金损失或未结算金额；标准订单、渠道交易、零现金订单和重复通知基数本就可能不同。未做按账户金额和跨表引用核对。

## 3. 接口目录证据

| 接口 | 目录分类 | Routine | 数据导出源行 |
|---|---|---|---:|
| `S231202504240686` | App | `K_GetManageHome` | 4373848 |
| `S231202504240687` | 服务器 | `K_PayCallback` | 4373849 |
| `S231202504280689` | App | `k_getBillList` | 4373851 |
| `S231202505150714` | App | `k_getOrderInfo` | 4373876 |
| `S231202505150715` | App | `k_setOrderInfo` | 4373877 |
| `S231202505150716` | App | `k_setGoodsBill` | 4373878 |
| `S231202506050734` | App | `K_getGoodsList` | 4373896 |
| `S231202506060735` | 服务器 | `K_GetBuyGoodsPayInfo` | 4373897 |
| `S231202506080736` | App | `K_GetMyMoney` | 4373898 |

## 4. 重点 Routine 及直接候选表

| Routine | CREATE 行（仅结构） | 直接表候选（含 schema 限定名） |
|---|---:|---|
| `K_getGoodsList` | 60889 | `k_goods`、`k_goods_classification`、`k_order`、`k_order_detail`、`k_stand_order`、`k_table`、`k_user` |
| `getGoodsInfo` | 36534 | `k_goods` |
| `K_GetMyMoney` | 61381 | `k_balance_details`、`k_diamond_detail`、`k_goldcoin_detail`、`k_items_goods`、`k_stored_items`、`k_wallet` |
| `K_GetBuyGoodsPayInfo` | 59969 | `k_order`、`k_table`、`k_transaction` |
| `k_GetPayConfigInfo` | 62233 | `t_alipay_config`、`t_bcs_config`、`t_wxpay_config` |
| `K_BuyGoods_Callback_Funtion` | 58084 | `k_order_detail`、`k_stand_order` |
| `K_PayCallback` | 63669 | `k_conversations_messages`、`k_order_member`、`k_stand_order`、`k_stored_items`、`k_transaction`、`k_transaction_notify`、`k_user`、`k_user_relation`、`k_wallet` |
| `k_getOrderInfo` | 61686 | `k_balance_details`、`k_config`、`k_goods`、`k_goods_detail`、`k_order`、`k_order_detail`、`k_order_member`、`k_stand_order`、`k_user`、`k_user_relation`、`k_wallet` |
| `k_setOrderInfo` | 66978 | `k_order`、`k_order_member`、`k_stand_order`、`k_user_relation`、`k_wallet` |
| `k_setGoodsBill` | 66825 | `k_order_detail` |
| `K_GetManageHome` | 61085 | `k_balance_details`、`k_stored_items`、`k_user_relation`、`k_wallet` |
| `k_getBillList` | 59718 | `k_balance_details`、`k_bill_detail`、`k_diamond_detail`、`k_goldcoin_detail`、`k_stand_order`、`k_wallet` |
| `k_SetBillDetail` | 64952 | `k_bill_detail`、`k_stand_order`、`k_stand_order_type`、`k_user` |
| `k_setCount_balance` | 65259 | `k_balance_details`、`k_bill_detail`、`k_stand_order_type`、`k_system_messages`、`k_user` |
| `k_setCount_Goldcoin` | 66016 | `k_bill_detail`、`k_goldcoin_detail`、`k_system_messages`、`k_user` |
| `K_refundOrderMoney` | 63924 | `k_order`、`k_order_member`、`k_refund_transaction`、`k_stand_order`、`k_transaction`、`t_wxpay_config` |

词法结果含注释/分支上界，不能当每次写表列表。特别是全局回调包含预约/红包，commerce 不因此取得聊天数据写权限。非 K_ 的 id_config、t_wxpay_config、t_alipay_config、t_bcs_config 只作为公共依赖，不导出配置行。

## 5. 原字段字典（结构，不含数据值）

以下是选定源表的原字段类型和注释，保留拼写以便追溯；不是新字段命名建议。共同 rowId/id/createdDate/updatedDate/indexed/deleted 的含义：物理键/业务组合键/记录时间/索引同步标记/软删除。新对象处理原则见 [数据设计](DATA_DESIGN.md)。最终逐字段去向仍待详细模型评审，不能将本字典当作已完成 ETL 映射。

### k_goods

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `goodsId` | `varchar(255)` | 物品id |
| `goodsName` | `varchar(255)` | 名字 |
| `goodsFullName` | `varchar(255)` | 全名 |
| `barcode` | `varchar(255)` | 条形码 |
| `classificationId` | `varchar(255)` | 分类id 关联k_goods_classification |
| `iconImage` | `varchar(500)` | icon图片 |
| `appImage` | `varchar(500)` | app展示图 |
| `goodsImage` | `varchar(255)` | 图片 |
| `describe` | `longtext` | 介绍描述 |
| `goodsProperty` | `int(2)` | 商品属性 0=单品，1=套餐 |
| `goodsStatus` | `int(2)` | 商品状态 0=停售，1=正常 |
| `goodsRegistDate` | `datetime(3)` | 录入时间 |
| `registId` | `varchar(255)` | 录入人ID 关联k_user |
| `batchId` | `varchar(255)` | 批次 关联k_goods_batch |
| `buyingPrice` | `decimal(10,2)` | 进货价 |
| `originalPrice` | `decimal(10,2)` | 原价 |
| `discountPrice` | `decimal(10,2)` | 折扣价 |
| `sorting` | `int(11)` | 人工排序 |
| `svgWidth` | `decimal(10,2)` | svg宽 |
| `svgHeight` | `decimal(10,2)` | svg高 |
| `svgImage` | `longtext` | svg图片 |
| `goodsSpecs` | `varchar(255)` | 规格 |

### k_goods_classification

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `classificationId` | `varchar(255)` | 分类 |
| `classificationType` | `int(1)` | 属性 0=实物、1=虚拟商品 |
| `name` | `varchar(255)` | 名字 |
| `describe` | `longtext` | 介绍描述 |
| `image` | `varchar(255)` | 图片 |
| `parentId` | `varchar(255)` | 父级ID |
| `deep` | `int(2)` | 层级 |
| `sorting` | `int(5)` | 手工排序 |

### k_goods_detail

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `detailId` | `varchar(255)` | 详情id |
| `goodsId` | `varchar(255)` | 商品id 关联k_goods |
| `goodsName` | `varchar(255)` | 商品名 |
| `goodsNumber` | `int(2)` | 商品数量 |
| `parentId` | `varchar(255)` | 父类id 关联k_goods 中的goodsProperty=1的goodsId |
| `buyingPrice` | `decimal(10,2)` | 进货价 |
| `originalPrice` | `decimal(10,2)` | 原价 |
| `discountPrice` | `decimal(10,2)` | 折扣价 |
| `sorting` | `int(11)` | 人工排序 |
| `unit` | `varchar(255)` | 单位 |

### k_goods_property

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `propertyId` | `varchar(255)` | 属性ID |
| `barcode` | `varchar(255)` | 关联商品条码 |
| `sorting` | `int(11)` | 人工排序 |
| `manufacturerId` | `varchar(255)` | 制造商编号 关联企业表 |
| `companyId` | `varchar(255)` | 出品商编号 关联企业表 |
| `goodsBody` | `text` | 商品简要描述 |
| `goodsPage` | `longtext` | 详细介绍的网页代码 XML/或HTML |
| `goodsShelfLife` | `decimal(10,2)` | 保质期限 保质期跟单位走 |
| `goodsShelfLifeUnit` | `int(2)` | 保质期单位 0=小时，1=天，2=月，3=年 |
| `goodsMinUnit` | `varchar(255)` | 最小单位 |
| `goodsSpecs` | `varchar(255)` | 规格描述 |
| `goodsColorRGB` | `varchar(255)` | 颜色类别RGB值 R,G,B 分别以逗号分割 |
| `goodsColorEn` | `varchar(255)` | 颜色类别短码值 #FFFFFF |
| `goodsSizeLong` | `double` | 长 长 |
| `goodsSizeWidth` | `double` | 宽 宽 |
| `goodsSizeHeight` | `double` | 高 高 |
| `goodsWeight` | `decimal(10,4)` | 重量 |
| `goodsWeightUnit` | `int(2)` | 重量单位 0=毫克，1=克，2=公斤 |
| `propertyStatus` | `int(2)` | 属性状态 0=无效，1=有效 |
| `goodsArea` | `varchar(255)` | 产地 |

### k_batch

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `batchId` | `varchar(255)` | 酒水批次id |
| `batchRequestId` | `varchar(255)` | 申请人ID |
| `batchPurchaseId` | `varchar(255)` | 采购人ID |
| `batchCheckId` | `varchar(255)` | 验货员ID |
| `batchLeaderId` | `varchar(255)` | 负责人ID |
| `batchStoreId` | `varchar(255)` | 仓库保管员ID |
| `batchRequestDate` | `datetime(3)` | 批次申请日期 |

### k_goods_batch

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `goodsBathId` | `varchar(255)` | 商品小批次ID |
| `goodsId` | `varchar(255)` | 关联商品ID |
| `barcode` | `varchar(255)` | 关联条码 |
| `propertyId` | `varchar(255)` | 关联商品属性ID |
| `goodsPrice` | `decimal(16,2)` | 商品本批次定价 适合选择了批次定价 |
| `goodsMinPrice` | `decimal(16,2)` | 本批次最小单价 最低出售底价 |
| `goodsCost` | `decimal(16,2)` | 进货单价 进货的成本单价 |
| `batchPlanNumber` | `decimal(10,2)` | 计划进货数量 申请进货数量 |
| `batchRealityNumber` | `decimal(10,2)` | 实际进货数量 批准进货数量 |
| `batchSendNumber` | `decimal(10,2)` | 实际发货数量 厂家发货数量 |
| `batchRequestDate` | `datetime(3)` | 申请日期 |
| `batchCheckDate` | `datetime(3)` | 批准日期 |
| `batchFromDate` | `datetime(3)` | 发货日期 |
| `batchId` | `varchar(255)` | 批次ID 商品关联批次 |
| `batchDesc` | `text` | 备注 |
| `registId` | `varchar(255)` | 操作员Id |
| `goodsStandPrice` | `decimal(10,2)` | 统一指导价格 |

### k_warehouse

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `warehouseId` | `varchar(255)` | 仓库登记ID 唯一 |
| `warehouseType` | `int(2)` | 仓库登记类型 0=入库单godown entry，1=出库单outbound delivery order，2=盘点check |
| `batchId` | `varchar(255)` | 批号 盘点则为盘点ID |
| `goodsBathId` | `varchar(255)` | 批次 |
| `siteId` | `varchar(255)` | 仓库位置ID 关联k_goods_warehouse_location表,0=默认 |
| `registId` | `varchar(255)` | 送货人操作员ID |
| `warehouseManageId` | `varchar(255)` | 仓库管理员ID |
| `goodsId` | `varchar(255)` | 商品id |
| `propertyId` | `varchar(255)` | 商品属性名称 |
| `goodsSpecs` | `varchar(255)` | 规格 |
| `goodsCost` | `decimal(10,2)` | 成本单价 |
| `goodsPrice` | `decimal(10,2)` | 商品本批次定价 |
| `entryNumber` | `decimal(10,2)` | 进库变动数量 |
| `outNumber` | `decimal(10,2)` | 出库数量 |
| `warehouseDesc` | `text` | 说明 |

### k_goods_warehouse_location

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `locationId` | `varchar(255)` | 位置id |
| `name` | `varchar(255)` | 位置名称 |
| `content` | `longtext` | 位置描述 |

### k_goods_access_log

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `storageId` | `varchar(255)` | 存酒Id |
| `userAccount` | `varchar(255)` | 用户Id 关联k_user |
| `goodsId` | `varchar(255)` | 商品id 关联k_goods |
| `goodsName` | `varchar(255)` | 物品名 |
| `goodsType` | `varchar(255)` | 物品类型 关联k_warehouse_location |
| `pic` | `varchar(255)` | 照片 |
| `type` | `int(2)` | 存取类型 0=存、1=取 |
| `locationId` | `varchar(255)` | 位置 关联k_goods_warehouse_location |
| `operateUserAccount` | `varchar(255)` | 操作用户Id 关联k_user |

### k_shop_thing

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `thingId` | `varchar(255)` | 业务id |
| `thingName` | `varchar(255)` | 物品名 |
| `classifyId` | `varchar(255)` | 分类id |
| `thingDescribe` | `varchar(255)` | 物品描述 位置、编号、型号描述等 |
| `thingImg` | `varchar(255)` | 物品图片 |
| `thingStatus` | `int(1)` | 物品状态 0=正常，1=不正常 |
| `lastCheckData` | `varchar(255)` | 最后检查时间 |

### k_shop_thing_check_log

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `logId` | `varchar(255)` | 业务id |
| `thingId` | `varchar(255)` | 物品id |
| `classifyId` | `varchar(255)` | 物品分类id |
| `checkStatus` | `int(1)` | 检查状态 0=正常，1=不正常 |
| `checkDescribe` | `longtext` | 检查描述 |
| `checkImgs` | `longtext` | 检查现场图片 多张图片使用英文逗号分隔 |
| `userAccount` | `varchar(255)` | 检查用户id |

### k_shop_thing_classify

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `classifyId` | `varchar(255)` | 业务id |
| `classifyName` | `varchar(255)` | 分类名 |
| `classifyDescribe` | `varchar(255)` | 分类描述 |
| `classifyType` | `int(1)` | 分类类型 0=设备，1=场地 |
| `deep` | `int(2)` | 层级 |
| `sort` | `int(4)` | 排序 |
| `parentId` | `varchar(255)` | 父级 |

### k_table

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `tableId` | `varchar(255)` | 卡座ID |
| `name` | `varchar(255)` | 名称 例如: 卡座888 |
| `describe` | `longtext` | 描述 |
| `image` | `varchar(255)` | 照片 |
| `type` | `int(1)` | 类型 0=卡座，1=包厢 |
| `seatNum` | `int(2)` | 座位数 |
| `status` | `int(1)` | 状态 0=空置中，1=使用中，2=被预定，3=打扫中 |
| `minConsumption` | `decimal(10,2)` | 最低消费金额 |
| `minBeauty` | `int(3)` | 最低颜值 0=不限制 |
| `maxAge` | `int(3)` | 最大年龄 0=不限制 |

### k_order

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `orderId` | `varchar(255)` | 订单id 订单id |
| `tableId` | `varchar(255)` | 卡座、包厢号 关联k_table |
| `scheduledTime` | `datetime(3)` | 预定时间 |
| `totalSeatNum` | `int(2)` | 容纳最大人数 |
| `attribute` | `int(2)` | 属性 0=组局，1=一起玩 |
| `orderType` | `int(2)` | 订单类型 0=全付，1=AA付 |
| `planAAPeopleNumber` | `int(2)` | 计划分摊人数 |
| `actualAAPeopleNumber` | `int(2)` | 实际分摊人数 |
| `createOrderTime` | `datetime(3)` | 下单时间 |
| `userAccount` | `varchar(255)` | 制单人 关联k_user |
| `operateUserId` | `varchar(255)` | 专属服务员 关联k_user |
| `receivableAmount` | `decimal(10,2)` | 应收金额 |
| `actualAmount` | `decimal(10,2)` | 实收金额 |
| `discountTotalAmount` | `decimal(8,2)` | 优惠金额 |
| `agentCommissionAmount` | `decimal(8,2)` | 代理提成金额 |
| `orderStatus` | `int(2)` | 状态 0=对外公开，1=专属预定，2=保留，3=售罄 |
| `isOver` | `int(1)` | 是否清台 0=有效，1=结束 |
| `isSex` | `int(1)` | 是否男女比例1:1 0=否，1=是 |
| `minBoyBeauty` | `int(3)` | 男孩最低颜值 0=不限制 |
| `minGirlBeauty` | `int(3)` | 女孩最低颜值 0=不限制 |
| `minAge` | `int(3)` | 最小年龄 0=不限制 |
| `maxAge` | `int(3)` | 最大年龄 0=不限制 |
| `useCoupon` | `int(1)` | 是否可以用劵 0=不可以， 1=可以 |
| `useCoin` | `int(1)` | 是否可以用金币 0=不可以， 1=可以 |
| `useDiamond` | `int(1)` | 是否可以用钻石 0=不可以， 1=可以 |
| `useCash` | `int(1)` | 是否可以用现金 0=不可以， 1=可以 |

### k_order_detail

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `detailId` | `varchar(255)` | 详情ID |
| `orderId` | `varchar(255)` | 订单id 关联k_order |
| `standOrderId` | `varchar(255)` | 标准订单id 关联k_stand_order |
| `goodsId` | `varchar(255)` | 商品Id |
| `goodsOriginalPrice` | `decimal(10,2)` | 商品原价 |
| `goodsDiscountedPrice` | `decimal(10,2)` | 商品实付优惠价 |
| `goodsNum` | `int(4)` | 商品数量 |
| `goodsTotalOriPrice` | `decimal(10,2)` | 总原价 |
| `goodsTotalDisPrice` | `decimal(10,2)` | 总实付优惠价 |
| `goodsStatus` | `int(1)` | 是否上菜 0=未上，1=已经上菜了 |
| `userAccount` | `varchar(255)` | 上菜人 关联k_user |
| `statusDate` | `datetime(3)` | 上菜时间 |

### k_order_member

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `memberId` | `varchar(255)` | 成员ID |
| `orderId` | `varchar(255)` | 订单id 关联k_order |
| `userAccount` | `varchar(255)` | 用户Id 关联k_user |
| `age` | `int(3)` | 年龄 |
| `gender` | `int(2)` | 性别 0=未知，1=男，2=女 |
| `avatarUrl` | `varchar(255)` | 头像 |
| `payablePrice` | `decimal(10,2)` | 应付价格 |
| `preferentialPrice` | `decimal(10,2)` | 优惠价格 |
| `actualPrice` | `decimal(10,2)` | 实付价格 |
| `memberStatus` | `int(2)` | 成员状态 0=待入场，1=已入场，2=已离场 |
| `enterTime` | `datetime(3)` | 进入时间 |
| `leaveTime` | `datetime(3)` | 离开时间 |
| `payStatus` | `int(2)` | 支付状态 0=等待支付, 1=支付成功, 2=支付失败, 3=取消支付 |
| `failureTime` | `datetime(3)` | 失效时间 |

### k_order_temp

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `tempId` | `varchar(255)` | 临时id 临时id |
| `userAccount` | `varchar(255)` | 用户id 关联k_user |
| `reserveDate` | `datetime(3)` | 预定时间 |
| `tableId` | `varchar(255)` | 卡座id 关联k_table |
| `goodsId` | `varchar(255)` | 套餐id 关联k_goods |
| `actualAAPeopleNumber` | `int(2)` | 实际分摊人数 |
| `orderType` | `int(1)` | 订单类型 0=AA付，1=全付 |
| `orderStatus` | `int(1)` | 状态 0=对外公开，1=专属预定，2=保留，3=售罄 |
| `isHost` | `int(1)` | 是否做局长 0=否，1=是 |
| `isSex` | `int(1)` | 是否男女比例1:1 0=否，1=是 |
| `useCoupon` | `int(1)` | 是否可以用劵 0=不可以， 1=可以 |
| `useCoin` | `int(1)` | 是否可以用金币 0=不可以， 1=可以 |
| `typeId` | `varchar(255)` | 订单分类id |
| `subTypeId` | `varchar(255)` | 订单子分类id |
| `otherUserAccount` | `varchar(255)` | 交易对手id |
| `balancePayAmount` | `decimal(10,2)` | 余额实付金额 |
| `goldCoinPayAmount` | `int(10)` | 金币支付金额 |
| `couponId` | `varchar(255)` | 我的优惠券ID |
| `couponDiscountAmount` | `decimal(10,2)` | 优惠券抵扣金额 |
| `cashPayAmount` | `decimal(10,2)` | 现金支付金额 |
| `modeId` | `varchar(255)` | 支付模式 例如：微信：T298000000000003（JSAPI）、T298000000000010（App）；支付宝： |
| `giftCouponId` | `varchar(255)` | 支付后赠送优惠券商品ID |
| `giftGoldCoinNum` | `varchar(255)` | 支付后赠送金币 |
| `giftExperienceNum` | `varchar(255)` | 支付后赠送经验值 |
| `giftCreditScoreNum` | `varchar(255)` | 支付后加信用分 |
| `minBoyBeauty` | `int(3)` | 男孩最低颜值 0=不限制 |
| `minGirlBeauty` | `int(3)` | 女孩最低颜值 0=不限制 |
| `minAge` | `int(3)` | 最小年龄 0=不限制 |
| `maxAge` | `int(3)` | 最大年龄 0=不限制 |
| `tempStatus` | `int(1)` | 临时订单状态 0=临时保存中， 1=已支付创建订单 |
| `relationId` | `varchar(255)` | 关联正式订单号 关联k_transaction |

### k_stand_order

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `standOrderId` | `varchar(255)` | 标准订单id 订单id |
| `typeId` | `varchar(255)` | 订单分类id 关联k_stand_order_type |
| `subTypeId` | `varchar(255)` | 订单子分类id 关联k_stand_order_type |
| `orderId` | `varchar(255)` | 业务订单号 例如，关联k_order |
| `subOrderId` | `varchar(255)` | 业务子订单号 例如，关联k_order_member |
| `userAccount` | `varchar(255)` | 用户id |
| `otherUserAccount` | `varchar(255)` | 交易对手id 默认是公司用户 |
| `payableAmount` | `decimal(10,2)` | 应付金额 |
| `discountAmount` | `decimal(10,2)` | 优惠金额 |
| `payAmount` | `decimal(10,2)` | 实付金额 |
| `balancePayAmount` | `decimal(10,2)` | 余额实付金额 |
| `goldCoinPayAmount` | `decimal(10,2)` | 金币支付金额 |
| `couponId` | `varchar(255)` | 我的优惠券ID |
| `couponDiscountAmount` | `decimal(10,2)` | 优惠券抵扣金额 |
| `cashPayAmount` | `decimal(10,2)` | 现金支付金额 |
| `cashPayMode` | `varchar(255)` | 现金支付模式 |
| `giftCouponId` | `varchar(255)` | 支付后赠送优惠券商品ID |
| `giftGoldCoinNum` | `int(2)` | 支付后赠送金币 |
| `giftExperienceNum` | `int(2)` | 支付后赠送经验值 |
| `giftCreditScoreNum` | `int(2)` | 支付后加信用分 |
| `payStatus` | `int(2)` | 支付状态 0=预订单，1=支付完成，2=支付失败 |
| `payTime` | `datetime(3)` | 支付时间 |

### k_stand_order_type

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `typeId` | `varchar(255)` | 分类id |
| `typeName` | `varchar(255)` | 分类名 |
| `deep` | `int(2)` | 层级 0为顶级 |
| `parentId` | `varchar(255)` | 上级分类id |
| `sorting` | `int(4)` | 排序 |

### k_transaction

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `transactionId` | `varchar(255)` | 交易id |
| `standOrderId` | `varchar(255)` | 标准订单表 关联k_stand_order |
| `userAccount` | `varchar(255)` | 用户id 关联k_user |
| `outTradeNo` | `varchar(255)` | 业务订单号 |
| `tradeNo` | `varchar(255)` | 第三方交易流水号 |
| `chargeAmount` | `decimal(10,2)` | 发起金额 |
| `discountableAmount` | `decimal(10,2)` | 优惠金额 |
| `paymetAmount` | `decimal(10,2)` | 应付款金额 |
| `paidAmount` | `decimal(10,2)` | 实付金额 |
| `settleAmount` | `decimal(10,2)` | 结算金额 结算金额=实付金额-手续费-分佣金 |
| `feeRate` | `decimal(10,2)` | 手续费率 例如：1=百分之一 |
| `feeAmount` | `decimal(10,2)` | 手续费金额 |
| `commissionAmount` | `decimal(10,2)` | 分佣金额 |
| `proOrderJson` | `longtext` | 预定单下单信息 |
| `payChannel` | `varchar(255)` | 支付通道 CASH=现金，ALIPAY=支付宝，WEIPAY=微信，BCS=长沙银行，ABC=农业银行 |
| `modeId` | `varchar(255)` | 付款模式  关联t_mode表 |
| `linkPID` | `varchar(255)` | 关联配置表 关联配置表 关联对应支付通道的配置表，用来记录当时付款的真实收款账户 |
| `notifyStatus` | `int(2)` | 回调状态  回调状态 -1=预订单，1=待回调，2=回调完成，3=回调失败 |
| `orderType` | `int(2)` | 订单类型 回调类型 0=内部应用，1=开放平台第三方唤起 |
| `notifyType` | `int(2)` | 回调类型 回调类型 0=内部订单，1=第四方订单 |
| `notifyUrl` | `varchar(255)` | 回调地址 异步适用于第三方唤起 |
| `successUrl` | `varchar(255)` | 支付成功链接 适用于第三方唤起 |
| `settleStatus` | `int(2)` | 结算状态 0=未结算，1=结算到平台，2=代理分佣完成，3=冲正 |
| `requestDateTime` | `datetime(3)` | 请求支付时间 |
| `confirmDateTime` | `datetime(3)` | 确认支付时间 |
| `paymentDateTime` | `datetime(3)` | 支付时间 |
| `orderRemarks` | `varchar(255)` | 订单备注 |

### k_transaction_notify

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `notifyId` | `varchar(255)` | 唯一id |
| `notifyResult` | `varchar(255)` | 回调支付结果 |
| `outTradeNo` | `varchar(255)` | 交易号 如果typeId=0，这个字段就关联k_transaction；如果typeId=1，这个字段就关联k_refund_transaction；如果typeId=2，这个字段关联k_merchant_transfer |
| `notifyContent` | `longtext` | 回调内容 |
| `payChannel` | `varchar(255)` | 支付渠道 |
| `notifyType` | `int(2)` | 回调类型 0=自动回调，1=人工程序回调，2=强制回调 |
| `companyUser` | `varchar(255)` | 回调用户 平台用户 |
| `typeId` | `int(2)` | 记录类型 0=支付异步回调，1=退款异步回调，2=主动查询转账批次 |

### k_refund_transaction

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `refundId` | `varchar(255)` | 退款id |
| `standOrderId` | `varchar(255)` | 标准订单id 关联k_stand_order |
| `fromTransactionId` | `varchar(255)` | 交易订单 关联k_transaction |
| `outTradeNo` | `varchar(255)` | 平台交易流水号 |
| `outRefundNo` | `varchar(255)` | 退款流水号 |
| `refundFee` | `decimal(10,2)` | 申请退款金额 |
| `refundStatus` | `int(2)` | 退款状态 0=发起退款、1=已收到回调退款成功、2=已收到回调退款失败 |
| `requestDate` | `datetime(3)` | 请求日期 |
| `operateUserAccount` | `varchar(255)` | 退单操作者 |
| `needPayTotalAmount` | `decimal(10,2)` | 操作人支付总金额 |
| `balanceAmount` | `decimal(10,2)` | 从余额扣除金额 |
| `cashAmount` | `decimal(10,2)` | 现金支付支付金额 |
| `requestParameters` | `longtext` | 退单请求参数 |
| `notifyDate` | `datetime(3)` | 异步回调日期 |
| `transactionId` | `varchar(255)` | 微信订单号 |
| `wxRefundId` | `varchar(255)` | 微信退款单号 |
| `totalFee` | `decimal(16,2)` | 订单金额 |
| `settlementRefundFee` | `decimal(16,2)` | 退款金额 |
| `refundRecvAccout` | `varchar(255)` | 退款入账账户 |
| `refundAccount` | `varchar(255)` | 退款资金来源 REFUND_SOURCE_RECHARGE_FUNDS 可用余额退款/基本账户 REFUND_SOURCE_UNSETTLED_FUNDS 未结算资金退款 |
| `refundRequestSource` | `varchar(255)` | 退款发起来源 API接口VENDOR_PLATFORM商户平台 |
| `cashRefundFee` | `decimal(16,2)` | 用户退款金额 退款给用户的金额，不包含所有优惠券金额 |

### k_wallet

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `walletId` | `varchar(255)` | 钱包id |
| `userAccount` | `varchar(255)` | 用户id 关联k_user |
| `walletStatus` | `int(1)` | 钱包状态 0=被冻结、1=正常 |
| `balance` | `decimal(10,2)` | 钱包余额 |
| `walletType` | `int(1)` | 钱包分类 0=现金账户，1=赠送金账户，2=授信额度账户，3=提成分账户 |

### k_balance_details

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `detailsId` | `varchar(255)` | 明细变动id |
| `walletId` | `varchar(255)` | 钱包id 关联k_wallet |
| `userAccount` | `varchar(255)` | 用户id |
| `income` | `decimal(10,2)` | 收入 |
| `expense` | `decimal(10,2)` | 支出 |
| `balance` | `decimal(10,2)` | 余额 |
| `detailsType` | `int(2)` | 操作类型 0=收入，1=支出 |
| `accountType` | `int(2)` | 账户分类 0=现金账户，1=赠送金账户，2=授信额度账户，3=提成分账户 |
| `detailsProperty` | `int(2)` | 明细属性 0=充值赠送，1=订单支付，2=订单分佣，3=提现，4=退款，5=代金券 |
| `detailsSubProperty` | `int(2)` | 明细子属性 0=不详，1=消费支付，2=刷礼物购买金币支付 |
| `counterparty` | `varchar(255)` | 交易对手的钱包ID |
| `otherUserAccount` | `varchar(255)` | 交易对手的userAccount |
| `relationId` | `varchar(255)` | 关联id 例如：0关联表k_recharge_details的id |
| `detailsStatus` | `varchar(255)` | 状态 0=冻结，1=正常，2=异常交易需要手工解除冻结 |
| `detailsThawDate` | `datetime(3)` | 解冻日期 只有冻结状态有效 |
| `outTradeNo` | `varchar(255)` | 商户订单号 |
| `tradeNo` | `varchar(255)` | 支付流水号 |
| `detailsRemarks` | `longtext` | 备注 |

### k_goldcoin_detail

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `logId` | `varchar(255)` | 日志id |
| `userAccount` | `varchar(255)` | 用户id 关联k_user |
| `operateType` | `int(1)` | 操作类型 0=增加、1=减少 |
| `income` | `int(11)` | 收入 |
| `expense` | `int(11)` | 支出 |
| `balance` | `int(11)` | 分值余额 |
| `detailsProperty` | `int(2)` | 明细分类 0=签到、1=充值、2=转账收支、3=兑换礼物、4、扣手续费、5、奖励、7、收发红包、8、购买物品、9、兑换现金 |
| `counterparty` | `varchar(255)` | 交易对手 默认是公司用户 |
| `standOrderId` | `varchar(255)` | 关联订单 关联k_stand_order |
| `remarks` | `longtext` | 备注 |

### k_diamond_detail

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `logId` | `varchar(255)` | 日志id |
| `userAccount` | `varchar(255)` | 用户id 关联k_user |
| `operateType` | `int(1)` | 操作类型 0=增加、1=减少 |
| `income` | `int(11)` | 收入 |
| `expense` | `int(11)` | 支出 |
| `balance` | `int(11)` | 分值余额 |
| `detailsProperty` | `int(2)` | 明细分类 0=签到、1=充值、2=转账收支、3=兑换礼物、4、扣手续费、5、奖励、7、收发红包、8、购买物品、9、兑换现金 |
| `counterparty` | `varchar(255)` | 交易对手 默认是公司用户 |
| `standOrderId` | `varchar(255)` | 关联订单 关联k_stand_order |
| `remarks` | `longtext` | 备注 |

### k_bill_detail

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `billId` | `varchar(255)` | 业务id |
| `userAccount` | `varchar(255)` | 用户id |
| `typeId` | `int(1)` | 类型 0=订单，1=余额，2=金币，3=钻石，4=佣金，5=提现 |
| `content` | `longtext` | 消息内容 |
| `billStaus` | `int(1)` | 消息状态 0=已发送，1=已读，2=已删除 |

### k_commission_log

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `logId` | `varchar(255)` | 日志ID |
| `orderId` | `varchar(255)` | 订单id 关联k_order |
| `memberId` | `varchar(255)` | 成员id k_order_member |
| `userAccount` | `varchar(255)` | 用户Id 关联k_user |
| `proxyId` | `varchar(255)` | 获得提成的代理、服务员ID 关联k_proxy_commission |
| `personType` | `int(2)` | 分类 0=代理、1=楼面经理，2=服务员 |
| `commissionPrice` | `decimal(10,2)` | 提成金额 |

### k_division

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `divisionCode` | `varchar(255)` | 区化代码 |
| `divisionName` | `varchar(255)` | 区化名称 |
| `step` | `int(11)` | 台阶 0=顶层 |
| `parentId` | `varchar(255)` | 父级 关联 区化代码 |

### k_user_relation

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `relationId` | `varchar(255)` | 关系id |
| `userAccount` | `varchar(255)` | 用户id 关联k_user |
| `agenyType` | `int(1)` | 类型 0=普通用户、1=代理营销、2=服务人员、3=一楼经理、4=一楼其它人员、5=二楼餐厅经理、6=二楼KTV经理、7=股东 |
| `parentId` | `varchar(255)` | 父级 0=顶级 |
| `agencyStatus` | `int(1)` | 状态 0=停用、1=正常 |
| `commissionRate` | `decimal(10,2)` | 酒吧客户佣金率 |
| `serviceRate` | `decimal(10,2)` | 卡座服务佣金率 |
| `ktvRate` | `decimal(10,2)` | KTV服务佣金率 |
| `dinnerRate` | `decimal(10,2)` | 餐厅服务佣金率 |
| `standRate` | `decimal(10,2)` | 标准费率 适用于经理和管理人员 |

### k_withdrawal

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `withdrawalId` | `varchar(255)` | 提现id |
| `walletId` | `varchar(255)` | 要提现的钱包id 关联k_wallet |
| `detailsId` | `varchar(255)` | 明细变动id 关联k_balance_details |
| `money` | `decimal(10,2)` | 提现金额 |
| `withdrawalStatus` | `int(2)` | 提现状态 0=提现中，1=提现完成，2=提现失败 |
| `withdrawalDate` | `datetime(3)` | 发起提现日期 |
| `completeDate` | `datetime(3)` | 提现记录结束时间 提现完成、提现失败的时间 |
| `remarks` | `longtext` | 备注 |
| `cardId` | `varchar(255)` | 提现银行卡id 关联k_bank_card |
| `cardNumber` | `varchar(255)` | 银行卡号 |
| `bankName` | `varchar(255)` | 银行名简称 |
| `bankFullName` | `varchar(255)` | 银行名全称 |
| `userName` | `varchar(255)` | 用户真实姓名 |
| `userMobile` | `varchar(255)` | 手机号 |

### k_recharge_details

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `detailsId` | `varchar(255)` | 明细变动id |
| `walletId` | `varchar(255)` | 钱包id 关联k_wallet |
| `userAccount` | `varchar(255)` | 用户id |
| `amount` | `decimal(10,2)` | 充值金额 |
| `balance` | `decimal(10,2)` | 余额 |
| `paymentChannels` | `varchar(255)` | 支付渠道 |
| `outTradeNo` | `varchar(255)` | 商户订单号 |
| `tradeNo` | `varchar(255)` | 支付流水号 |
| `detailsRemarks` | `longtext` | 备注 |

### k_items_goods

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `itemsId` | `varchar(255)` | 物品id |
| `itemsName` | `varchar(255)` | 名字 |
| `itemsFullName` | `varchar(255)` | 全名 |
| `itemsType` | `int(1)` | 分类 0=推荐礼品，1=节日礼品，2=其它 |
| `iconImage` | `varchar(500)` | icon图片 |
| `appImage` | `varchar(500)` | app展示图 |
| `itemsImage` | `varchar(255)` | 大图 |
| `describe` | `longtext` | 介绍描述 |
| `itemsStatus` | `int(1)` | 商品状态 0=停售，1=正常 |
| `itemsProperty` | `int(1)` | 属性 0=不可购买，1=可以购买 |
| `getPrice` | `decimal(10,2)` | 购买单价 |
| `itemsUnit` | `int(1)` | 购买单位 0=金币，1=钻石，2=现金，3=能量值 |
| `svgWidth` | `decimal(10,2)` | svg宽 |
| `svgHeight` | `decimal(10,2)` | svg高 |
| `svgImage` | `longtext` | svg图片 |
| `itemsUsePrice` | `decimal(16,2)` | 使用计量 关联itemsType字段(0=折扣率,1=免票<金额,2=金额,3=商品编号,4=经验值,5=抽奖数量,6=倍率) |
| `expirationDate` | `int(4)` | 有效期 单位天 |
| `sorting` | `int(11)` | 人工排序 |

### k_stored_items

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `storedId` | `varchar(255)` | 货品ID |
| `userAccount` | `varchar(255)` | 关联用户id 关联k_user |
| `otherUserAccount` | `varchar(255)` | 交易对手 公司的账号是A00000000001 |
| `itemsId` | `varchar(255)` | 商品id 关联k_items_goods |
| `itemsType` | `int(2)` | 道具分类 0=折扣，1=免门票，2=抵用金额，3=换酒水实物商品，4=充经验值，5=抽奖，6=加倍速 |
| `income` | `int(11)` | 收入数量 |
| `expense` | `int(11)` | 支出数量 |
| `standOrderId` | `varchar(255)` | 关联订单 关联k_stand_order |
| `effectiveTime` | `datetime(3)` | 有效期 时间 |
| `storedType` | `int(1)` | 作废:操作类型 0=收进，1=转出使用 |
| `storedStatus` | `int(2)` | 作废:状态 0=有效、1=已使用 |
| `storedProperty` | `int(1)` | 属性 0=自己的，1=库存只能送人不能自己使用 |

### k_stored_items_log

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `logId` | `varchar(255)` | 日志ID 订单id |
| `userAccount` | `varchar(255)` | 关联用户id 关联k_user |
| `otherUserAccount` | `varchar(255)` | 交易对手 公司的账号是A00000000001 |
| `itemsId` | `varchar(255)` | 商品id 关联k_items_goods |
| `income` | `int(11)` | 收入数量 |
| `expense` | `int(11)` | 支出数量 |
| `storedId` | `varchar(255)` | 关联订单 关联k_stored_items |
| `storedProperty` | `int(1)` | 属性 0=自己的，1=库存只能送人不能自己使用 |

### k_stored_wine

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `storedId` | `varchar(255)` | 业主ID |
| `userAccount` | `varchar(255)` | 关联用户id 关联k_user |
| `goodsId` | `varchar(255)` | 商品id 关联k_goods |
| `number` | `int(2)` | 数量 |
| `capacity` | `decimal(8,2)` | 容量 |
| `orderId` | `varchar(255)` | 关联订单 关联k_order |
| `storedTime` | `datetime(3)` | 存酒时间 |
| `effectiveTime` | `datetime(3)` | 有效时间 |
| `extractTime` | `datetime(3)` | 取酒时间 |
| `storedStatus` | `int(2)` | 状态 0=有效、1=已取 |
| `locationId` | `varchar(255)` | 库房位置id 关联k_goods_warehouse_location |
| `storedUserAccount` | `varchar(255)` | 保存人员 关联k_user |
| `extractUserAccount` | `varchar(255)` | 取酒人员 关联k_user |
| `isRead` | `int(1)` | 是否查看 0=未读，1=已读 |

### k_drinks_access_log

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `storageId` | `varchar(255)` | 存酒Id |
| `userAccount` | `varchar(255)` | 用户Id 关联k_user |
| `wineId` | `varchar(255)` | 酒水id 酒水id 关联k_wine_detail |
| `wineName` | `varchar(255)` | 酒水名 |
| `orderId` | `varchar(255)` | 关联订单Id 关联k_order |
| `number` | `int(3)` | 数量 酒瓶数量 |
| `percentage` | `decimal(10,2)` | 单位量 例如：一半瓶子就填50 |
| `pic` | `varchar(255)` | 酒水照片 |
| `storageStatus` | `int(2)` | 存取类型 0=存酒、1=取酒 |
| `takeDate` | `datetime(3)` | 取酒时间 |
| `locationId` | `varchar(255)` | 位置 关联k_warehouse_location |
| `operateUserAccount` | `varchar(255)` | 操作用户Id |

### k_subject

| 字段 | 原类型 | 原注释 |
|---|---|---|
| `subjectId` | `varchar(255)` | 业务id |
| `subjectTitle` | `varchar(255)` | 话题标题 |
| `publishNum` | `int(10)` | 发布点击率 |
| `visitNum` | `int(10)` | 获赞点击率 |

## 6. 未覆盖项

未导出原始个人/交易行、手机号、地址、凭据或签名；未统计各人的余额。未验证现网是否已应用增量，未做金额对账、外键引用对账、迁移、SQL 执行或恢复测试。Java 里的 KGoodsWriteoffLog/KWarehouseLocation/KProxyCommission 与本快照缺表问题见审计 A11。
