# 旧系统链路分析与审计

状态：In Review。结论针对本地资料快照，不等于现网漏洞、损失或迁移完成的证明。

## 1. 来源及可信边界

| 来源 | 本轮核验 | 限制 |
|---|---|---|
| 小程序 `D:/WEB3_AI/KingClub-git` | `9299208 / 1.1.38`；index.js、project.private.config.json 有既存改动 | 只读当前内容；不等同微信线上构建 |
| Java `D:/2026-ZHUZHOU/SERVICES/wuyexin-service/wuyexin` | 内层 Git 可读到 `69f740bb0`；大量工作区差异，pack 的 `._` 索引报错 | 未修复、未清理；源码快照不能用 HEAD 单独描述 |
| SQL `D:/2026-ZHUZHOU/物业信数据库` | 两份指定导出文件指纹与先前盘点一致；源 MySQL 5.7.27 | 导出头日期原文 `07/06/2026`，不拿文件修改时间当线上更新时间 |
| App commerce worktree | 从主目录已提交的 `b1016d7` 创建；准备文档节点 `46c1ac0` | 不读取主目录未提交聊天代码作为 commerce 开发基线 |
| CCSOP `D:/2026-ZHUZHOU/SERVICES/ccsop-service` | 检查时 `35c428a`；有 .gitignore 及聊天构建等未提交内容 | 并行变化中；没有构建、运行或部署 |
| SUPERVM `D:/WEB3_AI/SUPERVM` | 检查时 `4a58ae11`，工作区干净 | 只读 README、认证契约、RPC/回执代码；未运行节点 |

用户输入的 `D:/WEB3/_AI/...` 对应本机实际存在的 `D:/WEB3_AI/...`，不新建另一套源目录。

SQL 指纹：

- 结构+数据：9,086,676,447 字节，SHA-256 `9d8235e17c5608246e702d1302cb2f593fbe8e4645a9fb0142e519b2a9737ad0`。
- 仅结构：4,970,220 字节，SHA-256 `d5a0a1bc3b2da8474c131ec38da2b4bfb9d4ea498bd2a7d043e6e347fb13fc0c`。
- 全库结构扫描识别 515 张表，其中 94 张 k_ 表；仅 K_ 行做数量和非个人枚举统计。结构扫描 9,869,824 行；3 个超长非接口行截断识别，接口目录未跳过。K_ 行统计独立解析，33,997 行，解析错误为 0。

## 2. 业务入口到数据库

分类沿 `s_interface.interfaceType → s_interface_type.typeId/parentId` 核对：酒吧根 `S232202502210097`，App `S232202502210099`，服务器端使用 `S232202502210100`。分类是目录信息，不是业务权限证明。

| 动作 / 旧入口 | 接口 / Java | Routine | 主要数据及副作用 |
|---|---|---|---|
| 扫桌台码 | index.js `scanCodeFun` 的 case 9 | 该分支解析字符串并导航 | tableId/shopId/tableName 进入 shoping；没有在此建立可信开台授权 |
| 商品/本桌已购商品 | shoping.js:135 → `S231202506050734`（App） | `K_getGoodsList` | 商品分类、商品、开台单、标准单、订单行、桌台、用户；套餐详情经 `getGoodsInfo` |
| 读取余额/金币/券 | shoping2.js:65 → `S231202506080736`（App） | `K_GetMyMoney` | 钱包、余额/金币/钻石流水、个人券与券目录；返回可用优惠与金额 |
| 创建商品支付 | shoping2/pay → `/kingclub/buyGoods` → KingClubService.java:1026 → `S231202506060735`（服务器） | `K_GetBuyGoodsPayInfo` | 新建/复用开台订单，生成支付交易并保存请求快照，调用支付配置函数 |
| 外部支付 | `KingCommonPayTool.toPayment / toPaymentV3` | `k_GetPayConfigInfo` 提供配置 | 第三方支付；依赖公共 `t_wxpay_config/t_alipay_config/t_bcs_config`，不能整表迁移凭据 |
| 微信回调 | `KingComNotify.wxPay / wxPayV3` → `callPayWxBack` → `S231202504240687`（服务器） | `K_PayCallback` | 支付回调日志、交易/标准订单、抵扣、奖励、账单、订单成员；其他分支还有红包聊天副作用 |
| 商品支付后明细 | 回调商品子类型 `K26100000015` | `K_BuyGoods_Callback_Funtion` | 订单商品行及标准订单；当前快照有待核实异常，见 A06 |
| 员工查看订单 | order-manage.js:408 → `S231202505150714` | `k_getOrderInfo` | 开台订单、用户/成员、商品等 |
| 订单经营状态调整 | order-manage.js:153 → `S231202505150715` | `k_setOrderInfo` | 多种 checkValue 分支的订单/成员操作；需逐动作拆分，不作为万能更新接口 |
| 标记上菜 | order-manage.js:211 → `S231202505150716` | `k_setGoodsBill` | 更新订单行 goodsStatus、上菜人、上菜时间；不等于出库或记账 |
| 管理员面板 | manage.js → `S231202504240686` | `K_GetManageHome` | 按 agenyType 拼菜单，提成钱包、当月收入、券数量和可提现统计 |
| 会员及佣金账单 | mybalance/agencybalance → `S231202504280689` | `k_getBillList` | k_bill_detail 聚合展示，关联标准订单与分类资产流水；不是总账凭证 |
| 批次/出入库后台 | Java `web-view/pages/kbatch、kgoodsbatch、kwarehouse`；`web-rest/apis/KGoodsBatchApi、KWarehouseApi` | 通用 service/mapper CRUD | 采购批次和出入库登记存在；业务工作流、审批及销售自动出库需要独立确认 |

目录具体源行见 DATA_INVENTORY。旧脚本的词法依赖识别会漏掉 `INSERT INTO nuggets.k_transaction` 这类 schema 限定名，本轮已用源 SQL 补查；不能把早先附件中的短表清单直接当完整事务范围。

## 3. 五个模块的真实含义

### 库存

商品主档 `k_goods`，规格/条码属性 `k_goods_property`，套餐组成 `k_goods_detail`。`k_batch` 保存申请、采购、验货、负责人、保管人；`k_goods_batch.goodsBathId` 是小批次业务键，包含计划/批准/发货数量及成本、定价等。

`k_warehouse` 的 warehouseType：0 入库、1 出库、2 盘点；数量在 entryNumber/outNumber，位置在 siteId。不能将此表重命名为 warehouse 主档后丢失流水含义。快照 30 行全部为类型 0，只能证明已有入库样本，不能推出完整当前库存数量。

审读的商品下单、支付回调和上菜链没有销售写入 k_warehouse；核查这些对象的触发器只更新时间，没有发现隐藏自动扣库存。Java 仓储页是 `createUpdate/delete` 通用编辑，等待 ES 索引的 3 秒 sleep 也说明它不是直接面向快速收银设计的界面。尚不能排除未提供版本/专用后台存在其他销售出库逻辑。

个人存酒/券、店内设备巡检、销售库存必须分开：k_goods_access_log 是存取物品记录，k_shop_thing* 是店内物品检查，不应冒充商品库存账。

### 收银

小程序 cash-register.js 只有加速度计/摇动计分，不能复用为营业收银。真实收款散布在点单、预约和 pay.js；管理端有订单、上菜、清台相关动作，但未见已验证的收银班次、钱箱实点、现金差额、交接与日结一体流程。

三种旧单据要保留区分：k_order 为桌台/预约聚合，k_stand_order 表示一次业务付款，k_transaction 表示支付渠道交易。它们不保证行数相等，不能以相等为对账条件。支付、上菜和清台是三个独立事实。

### 记账

k_wallet 区分现金、赠送金、授信、佣金四类；余额查询大量使用 `SUM(income)-SUM(expense)`。k_balance_details、k_goldcoin_detail、k_diamond_detail、k_stored_items* 等是不同资产流，单位和使用限制不同。k_bill_detail 主要保存会员账单类型与 JSON 内容，可读/删状态也属于展示，不是不可变总账。

佣金不能只看 k_commission_log：快照该表为空，但提成账单和佣金类余额流水有记录。`K_PayCallback` 注释标识分润在结算处理，注释掉的分佣块不算执行逻辑。找到的 `OrderSettleTask2` 操作的是 STransaction，不是 k_transaction，不能据此声称 KINGCLUB 自动结算已闭环。

没有在 94 张 K_ 快照表中找到完整会计科目、借贷凭证、期间结账及三张财务报表模型；k_subject 实际是话题。用户要求的完整财务属于新增设计。

### 扫码点单

旧流程已经包含单品/套餐、购物车、本桌已购、券/金币/余额组合、外部支付、上菜。商品查询按 goodsStatus=1 且有图片等条件筛选，没有关联真实可售库存；商店名称地址是过程内固定返回，shopId 不能证明已有多店商品隔离。

本地 orderDataList 按 tableId 和自然日复用；下单过程按当天 04:00 到次日 04:00 查单，商品已购查询按 CURDATE 查单。这些时间口径需要统一为营业日和本次开台，不将午夜后不同桌次混在一起。

### 商店

旧 shoping 是桌台点单商店原型，并非已经支持配送商城、线上自提与链上资产市场。商品主档、分类、套餐和券可参考；地址、运费、配送单、自提核销、链上资产交割需新增。

## 4. 审计事项

| 编号 | 事实 / 待验证问题 | 影响与新设计要求 |
|---|---|---|
| A01 | cash-register.js 的实现与“收银台统计”菜单名不符 | 重做收银任务流，不以旧页面存在作为完成依据 |
| A02 | 商品列表未关联 k_warehouse；上菜过程仅更新订单行 | 用户明确要求实时库存，需设计下单占用、自动出库、缺货禁售和每日盘点 |
| A03 | 小程序、Java buyGoods、K_GetBuyGoodsPayInfo 传递/保存客户端金额及奖励；审读链未见完整服务端重算 | 可信商品版本、套餐组成、活动/资产规则由服务端报价，不接受客户端金额作为事实 |
| A04 | 下单过程有 START TRANSACTION/异常 handler/ROLLBACK；回调有 payStatus<>1 检查 | 保留原子业务意图；单次事务和读状态检查不等于并发锁/唯一幂等键，需并发回调对照验证 |
| A05 | KingComNotify.wxPay 直接转发 return_code；wxPayV3 解密后传事件，签名参数在已审方法中未参与验签；未见完整商户/金额核对 | 仅为本地方法审计，外围过滤/线上版本未核验；新适配器必须验证原文签名、商户、订单、币种、金额，业务提交后才确认回调 |
| A06 | 快照 K_BuyGoods_Callback_Funtion 使用 @requestStr 而非入参，出现 `discopay_AmountuntPriceTemp`；标准单在该函数创建，但回调先读取标准单以确定子类型 | 源码/SQL可能不对应最终版本；建立最小恢复与调用用例核实，不以拼写替换宣称支付修好 |
| A07 | 回调末尾 `SET t_error = setStatus`，失败分支出现 `transactionld`；日志插入在业务事务之前 | 错误标记可能被覆盖、失败状态可能不完整，日志不随业务回滚属独立边界；需恢复演练验证，不笼统声称旧系统无事务 |
| A08 | K_GetBuyGoodsPayInfo 的 04:00 窗口、商品查询自然日、本地购物车日期不同；查桌单未见唯一活动开台键 | 明确营业日，跨午夜及多人同桌并发不重复开单；购物车按账号/门店/开台隔离 |
| A09 | shoping2.js:79 的优惠券默认选择引用未定义 items_list；pay.js mode=8/支付 SDK success 直接展示成功 | 作为旧快照缺陷记录；新端仅凭服务端确认显示已付款，超时显示确认中，不能重复支付 |
| A10 | 库存等 REST CRUD、菜单 agenyType 及上菜过程本身不提供完整门店/员工对象授权证据 | 新接口以可信会话及资源权限校验，不能只隐藏按钮或允许直接改表 |
| A11 | Java 有 KGoodsWriteoffLog/KWarehouseLocation/KProxyCommission 对象，指定 94 表快照缺少对应表 | 建立来源差异清单；缺表不从 b_/s_/物业表任意替代，也不凭 Java 对象自动创建生产表 |
| A12 | k_wallet.balance 与流水推导金额并存；335 条余额流水软删除；支付/结算状态有未完成样本 | 导出只能看历史截面；迁移须逐账户、资产、状态和期初对账，不重播历史奖励、不默认复制汇总余额 |
| A13 | 当前 App commerce 直接依赖 FakeCommerceRepository；CCSOP payment 仅 mock-payment | 新模块尚无真实交易闭环；现有 UI/Mock 不算新范围已验收 |
| A14 | VM 有原生交易/回执入口，未找到 KINGCLUB 商店业务适配 | NOVORUDP 传输到达、VM 入队、执行回执、商业交割是不同阶段，需明确定义何时算成交 |

## 5. 原子范围与公共依赖

schema 限定名补查后，`K_GetBuyGoodsPayInfo` 直接涉及 k_order、k_table、k_transaction；递归含 id_config 及三类支付配置。`K_PayCallback` 递归涉及订单/明细/标准订单、交易/回调、钱包/余额/金币、个人券及其流水、经验、会员、系统账单/通知，预约和红包分支还涉及订单成员及聊天消息。

此清单是包含其他子类型的词法依赖上界，含注释候选，不代表扫码点单每次都会写全部表。新设计需按 `商品支付`、`预约支付`、`红包` 等用例隔离，commerce 不直接修改聊天表。公共配置、ID 生成、支付路由/凭据仅登记依赖，不取得整表迁移许可。

## 6. 可复现定位

旧小程序根下：`pages/shoping/shoping.js`、`pages/shoping2/shoping2.js`、`pages/pay/pay.js`、`pages/manage/manage.js`、`pages/cash-register/cash-register.js`、`pages/order-manage/order-manage.js`、`pages/mybalance/mybalance.js`。

Java 内层根下：

- `web-rest/src/main/java/com/western/nuggets/web/rest/kingclub/KingClubApi.java`：buyGoods 入口。
- `service-business-service/src/main/java/com/western/nuggets/service/wyx/kingclub/KingClubService.java`：buyGoods 1026 行附近。
- 同目录 `KingCommonPayTool.java`、`KingClubMapper.java`：支付通道与交易查询。
- `web-view/src/main/java/com/western/nuggets/web/view/hk/KingComNotify.java`：wxPay 约 60 行、wxPayV3 约 100 行、callPayWxBack 约 153 行。
- `web-view/src/main/java/com/western/nuggets/web/view/pages/kwarehouse/KWarehousePage.java`：45 行附近通用编辑与等待 ES。
- `web-rest/src/main/java/com/western/nuggets/web/rest/apis/KGoodsBatchApi.java`：通用 CRUD，不等同采购完整流程。

SQL 精确 CREATE 行、字段和接口原始行号见附件。未运行任何旧回调、真实付款、退款、出库或修复 SQL。

## 最新业务专项补查

[AA、多门店与语言专项审计](SUPPLEMENTAL_AUDIT.md) 补充旧组局/加入支付、男女名额、内部物品核销和新服务隔离基线；已区分发现的旧能力、待整改差异与尚未证实的第三方平台接入。
