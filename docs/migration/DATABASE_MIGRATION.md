# 数据库拆分与迁移设计

## 核心结论

不要按客户端简单复制三套完整数据库。应按数据所有权拆分：

- 共享自然人身份
- 每个 App 独立账号成员关系和资料
- 可选共享同城社交能力
- KingClub 交易和门店数据独立
- 其他 App 的业务数据各自独立

## 推荐标识体系

```text
person_id        自然人全局 ID，不直接暴露给客户端
account_id       登录账号 ID
app_id           产品/App 标识
app_user_id      某 App 内的用户 ID
legacy_user_id   旧系统 userAccount 映射
tenant_id        如未来有门店/机构租户，再单独使用
```

不要把 `app_id`、`tenant_id` 和 `person_id` 混成一个概念。

## 用户资料建议

```text
person
  person_id
  verified_identity_ref

account
  account_id
  person_id
  mobile/login_identifier

app_membership
  app_user_id
  app_id
  person_id
  status
  joined_at

app_profile
  app_user_id
  nickname
  avatar
  app_specific_fields

legacy_identity_map
  source_system
  legacy_user_account
  person_id
  app_user_id
```

同一个人可以在不同 App 使用不同昵称、头像、状态和授权范围。

## 数据库部署阶段

### 阶段 A：同实例逻辑隔离

- `identity` schema/database
- `city_social` schema/database
- `kingclub` schema/database
- `messaging` schema/database

优点是成本低、迁移容易。代码层必须禁止随意跨域 JOIN。

### 阶段 B：服务边界隔离

- 各领域只能通过自己的 Repository 访问数据。
- 其他领域通过 API 或领域事件获取信息。
- 引入 Outbox 表和消息投递。

### 阶段 C：按需要物理分库

当出现以下条件时再迁移独立实例：

- 数据量或连接数显著增长
- 某领域需要独立扩容
- 发布故障需要隔离
- 不同产品团队独立维护
- 数据生命周期明显不同

## 数据迁移步骤

1. 冻结旧表结构的无计划修改。
2. 建立旧表、字段、主外键和接口使用关系清单。
3. 给所有旧用户建立 person/app_user 映射。
4. 建立新表并执行一次全量迁移。
5. 用校验脚本比较数量、金额、状态和关系。
6. 开启旧库到新库的增量同步或 Outbox 双写。
7. API v2 先只读新库，旧 API 保持不变。
8. 小范围用户切换新写路径。
9. 扩大灰度并持续对账。
10. 停止旧写入，保留只读回滚窗口。

## 一致性规则

- 订单、支付、余额必须做金额对账，不能只比记录数量。
- 好友、关注、黑名单必须验证双向/单向语义。
- 用户资料迁移要保留来源、时间和版本。
- 文件和图片迁移要校验对象存在性，不只迁 URL。
- 不使用分布式事务连接所有领域；优先使用本地事务 + Outbox + 幂等消费者。

## 必须先回答的数据问题

- “同城个人用户信息”是否在所有 App 中属于相同业务目的？
- 用户是否需要一个账号登录所有 App？
- 昵称、头像、实名认证、手机号分别允许共享到什么程度？
- 好友、关注、聊天关系是否跨 App 可见？
- 金币、余额、会员权益是否跨 App 通用？
- 门店和代理是否属于 KingClub，还是平台级资源？
- 旧数据库使用什么引擎和版本？
- 当前总表数、数据量、最大表、日增量和峰值 QPS 是多少？

