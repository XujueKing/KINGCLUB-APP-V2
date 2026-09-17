# AA、多门店与语言专项补查

日期：2026-09-17。仅本地源码/SQL 只读审计，无数据库执行、平台核销、真实支付或设备操作。以下补充基础审计，不宣称完整运行验证。

## 旧 AA 与订台证据

旧小程序根目录 D:/WEB3_AI/KingClub-git：
- pages/vip-order/vip-order.js:72–74 有 actualAAPeopleNumber、isSex、orderType；176 调 S231202505110708，668 调 createPayOrderTwo。
- pages/Choose2/Choose2.js:341 调 S231202505110707。
- pages/order2/order2.js:288 调 S231202504160684；528 调 createPayOrder。
- pages/pay/pay.js:57、70 分别区分组局与已有 orderId 的 AA 下单。

旧 Java 根目录 D:/2026-ZHUZHOU/SERVICES/wuyexin-service/wuyexin：
- web-rest/src/main/java/com/western/nuggets/web/rest/kingclub/KingClubApi.java:133、150 为两种下单入口。
- service-business-service/src/main/java/com/western/nuggets/service/wyx/kingclub/KingClubService.java:748、792、817 将卡座、套餐、人数、配比等传给 S231202505110709；699 对应 S231202504070678。
- 这些字段从请求传入，不意味着前端选项已经得到完整服务端授权、数量和金额验证。

结构来源为 nuggets-仅结构.sql，接口映射来源为同目录结构+数据快照的已生成元数据，不包含业务行：

| 接口 | Routine | 结构 LF 行号 | 核查结果 |
|---|---|---:|---|
| S231202505110707 | K_GetReserveInfoTwo | 62557 | 返回预约、男女占位人数、参加成员；计数包括未过期占位和已付款 |
| S231202505110708 | K_GetCanSelectData | 60107 | 获取可选桌台和套餐；套餐内容来自 k_goods_detail |
| S231202505110709 | K_CreateToSeat | 58659 | 读取 seatNum/商品价格，写 k_order_temp，创建支付配置，有事务/回滚 |
| S231202504070678 | K_getOrderPayInfo_v2 | 62029 | 写成员、标准订单及交易，15 分钟付款占位，有事务/回滚 |
| S231202504160684 | K_getOrderMore | 61807 | 查询会员可用内部资产及订单规则 |
| S231202504070676 | K_listenCode | 63202 | 查询 k_stored_wine 或 k_stored_items 状态 |

## 关键差异

1. K_getOrderPayInfo_v2 在 62096–62100 读取局配置并 COUNT 同性成员，只有 isSex=1 时按总座位一半判断；本过程未见相应 FOR UPDATE 或原子名额占用。存在事务不等于已证明最后名额并发安全。无配比场景的总容量校验也不能由这段同性检查代替。新设计须同时验证总人数和配置配比，具体索引/锁在详细设计中明确。
2. 62130–62132 对同一天其他订单的未付成员做取消，未见门店/租户条件。此逻辑不能直接搬到多店平台，可能影响其他店或其他场次的有效意图；新模型按明确场次和业务冲突规则判断。
3. K_GetCanSelectData 可选桌台/套餐查询未见经营主体或门店过滤；K_GetReserveInfoTwo 中当前阅读的查询也不能证明完整跨商户隔离。不能用旧表已有 tableId 代替租户授权。
4. 旧代码有 AA 字段和占位，不等于已实现本次“任意加餐商品、逐人先付款、达到人数才统一成单出库、未成团自动逐笔退款”。这条仍作为新流程设计。
5. pages/savecode/savecode.js:149–165 轮询 K_listenCode，根据内部存储状态显示已取出/已核销。这不是抖音/美团官方券核销证据。
6. 对旧小程序 JS（排除依赖目录）及旧服务 web-rest/src、service-business-service/src Java 搜索 douyin/meituan/抖音/美团，未找到对应接入命中。搜索范围之外、动态接口内容或生产配置仍可能另有实现；不作“旧平台绝无此功能”的结论。正式接入前需明确官方商家授权与可调用渠道，不模拟成功。

## 新服务隔离能力初查

对 D:/2026-ZHUZHOU/SERVICES/ccsop-service/src 的 TypeScript 搜索 tenant/Tenant/storeId/store_id/shopId/organizationId，未找到可确认的多商户门店经营隔离实现；唯一 restoreIdentity 命中属于词内误匹配。business-lines/kingclub/business-line.config.ts 体现 KingClub 业务线和适配器选择，不能证明“一业务线内多老板、多品牌、多店”已具备。

这是入口检索和经营相关源码初查，不是完整安全审计，也不排除其他命名/外部网关。新平台必须显式落实经营主体、门店和授权关系后再接真实数据。

四语言基线和缺口见 [全平台四语言设计](LANGUAGES.md)。本轮不改公共 App、不改聊天、不连接第三方平台。

## 后续详细设计要补的证据

需在相关开发前明确第三方券核销授权/接口契约、既有组织与门店模型实际来源、支付回调与 AA 关闭退款竞态、唯一约束/锁顺序、门店账套与收款主体、语言资源及打印设备能力。本轮已完成静态路径定位和差异说明，未把这些未验证能力标记为已通过。
