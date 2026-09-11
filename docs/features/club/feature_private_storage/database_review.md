# KC-F-026 储物数据审查（2026-09-12）

## 后续单会员授权迁移已完成

用户明确授权本人手机号对应的旧酒和券迁入新App。已读取实时旧库并核对新手机号指纹唯一归属，执行备份、源二次对账、事务导入、服务投影对账及重复预演。过期酒保留原日期且不可提取；个人券按净余额，排除非个人库存及已使用券。真实标识和明细仅保留受限运维档案。此处覆盖下文此前“尚未迁移”的历史状态；不代表全量历史ETL或经营双系统切换完成。

界面日期按手机本地时区显示（当前会员手机为北京时间），酒瓶背面补充“已过期”；不改变数据库有效期。


状态：新独立库存核心已隔离验证并按用户明确要求部署；旧余额迁移仍为 Model In Review，未执行。不可把新接口上线等同于旧资产迁移验收。

## 来源与调用

只读旧小程序当前仓库（用户 index.js 改动保留）、仅结构 SQL 及接口目录。结构文件使用GB18030；不把9GB数据快照或个人记录写入仓库。

| 入口 | 旧接口 / Routine | 依赖 |
|---|---|---|
| index 储物柜 | S231202504070675 / K_getBoxList，分类S232202502210099 | k_stored_wine、k_goods、k_stored_items、k_items_goods；getTabMsgInfo |
| savecode / 员工详情 | S231202503110660 / K_GetStorageDetail，同分类 | 上述四表、k_user、k_user_relation、k_virtual_goods |
| 2秒轮询 | S231202504070676 / K_listenCode，同分类 | k_stored_wine、k_stored_items |
| getWine 员工更新 | S231202504070677，K_getUpdateWine | k_stored_wine、t_error；员工入口不属于消费者写权限 |
| 道具数量变更 | k_setCount_item | k_stored_items、k_stored_items_log |

getTabMsgInfo 还读 k_config、k_conversations、k_conversations_blacklist、k_conversations_messages、k_conversations_temp、k_coupon、k_system_messages；这些消息/角标副作用不并入新库存交易。K_getBoxList 会把本人存酒 isRead=1，新柜子尚无真实储物通知体系，不复制该旧库更新。旧员工权限来自 k_user_relation；新成员接口不接受员工角色自报。

## 字段去向与迁移约束

- k_stored_wine：storedId仅用于将来受控迁移映射；userAccount需确认独立会员归属；goodsId对应商品；number→quantity，capacity→remainingPercent（迁移前核对单位范围），storedTime/effectiveTime→UTC存入/失效时间。storedStatus/deleted结合业务映射，不能简单把所有记录标available。库位、存取员工、订单、isRead保留旧档案，不下发消费者。
- k_stored_items：按有效且storedStatus=0、storedProperty=0筛选；旧可用数量是SUM(income)-SUM(expense)，不是income单列。旧页面按itemsId聚合并显示最早有效期。新表按批次存有效期，迁移须保留批次及扣减顺序，禁止把各批次都套最早日期；不能直接复制旧列表聚合结果。
- k_goods/k_items_goods/k_virtual_goods→运营商品目录，当前只配置截图涉及的3种酒和AA券素材；未知商品不冒用图片。k_coupon/k_coupon_log、k_ticket_records不是同一种券余额，未授权混入。
- k_stored_items_log保留旧审计；新受信入库/提取写kingclubStorageEvent，requestId幂等、请求摘要与结果，原始短码不存储。
- 旧订单、券发放、AA抵扣、钱包、游戏、消息等跨域副作用尚未完整迁移，不能拿新主机提取操作替代所有旧消费交易。

## 新模型与一致性

031：Product目录、Holding独立会员批次余额、Pickup会话短码、Event幂等审计；四表三接口均目录登记。只有当前已通过会员可看本人数据。提取在事务内校验会话、状态、有效期和余额版本，行锁扣减；同请求重试复用结果，码重放拒绝。失败事务回滚，不报告已提取。

## ETL、对账、回滚

未迁移旧余额，真实新库存0条。迁移前需确认旧→新会员映射、基准时点、商品映射、capacity单位、批次有效期、已消费/软删除状态。异常归属或负净额先隔离；按会员/商品/批次核对数量及比例、外键和重复来源键。迁移需增加唯一来源映射并做干跑报表，不使用截图数值。旧库维持只读，不双写；新模块部署前备份，旧服务保留可回退。

验证：隔离MySQL001–031重建，所有权/参数拒绝/并发幂等/过期/重放/会话撤销/会员限制通过；线上登记4表3接口、0余额核验。旧余额ETL、员工UI、完整经营链路仍未验收。
