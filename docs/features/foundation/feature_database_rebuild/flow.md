# 数据库重建与迁移流程

## Phase A：结构与业务语义盘点

1. 冻结旧表的无计划结构变更。
2. 为 94 张 `k_` 表补充所有者、敏感等级、数据量、日增量和调用接口。
3. 提取旧 `s_interface`、Routine、客户端调用和表依赖矩阵。
4. 画出身份、聊天、订单、支付和钱包状态机。

## Phase B：目标模型

1. 确认数据库/部署边界。
2. 建立平台身份与 KingClub App 成员关系。
3. 建立 `legacyIdentityMap` 和各领域 legacy ID 映射。
4. 设计第一批登录与会话表。
5. 后续按领域设计社交、聊天、订单和资产表。

## Phase C：可重复 migration

1. 从空 MySQL 8.4 环境执行公版 migration。
2. 使用下一个可用编号新增 KingClub migration，不修改已执行 migration。
3. 每张新表登记 `databaseCatalogTable`。
4. 每个 Routine 登记 `databaseRoutineCatalog`。
5. 每个超级接口登记 `interface` 和分类关系。

## Phase D：数据迁移

1. 对旧库做一致性和孤儿记录扫描。
2. 全量迁移身份及映射。
3. 校验数量、唯一性、状态和敏感字段加密。
4. 再按业务域迁移数据。
5. 需要并行运行时使用 Outbox/增量同步，不直接无审计双写。

## Phase E：灰度与回滚

1. API v2 先读新库。
2. 选定测试账号进入新写路径。
3. 持续对账新旧结果。
4. 扩大灰度前验证回滚映射。
5. 旧库转只读并保留明确窗口。

