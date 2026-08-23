# 第一阶段：数据库、超级接口、登录鉴权与 WebSocket

- 文档状态：In Review
- 审计日期：2026-08-24
- 当前范围：只读资产审计与目标方案，不修改服务端、旧客户端或数据库

## 1. 输入资产

| 资产 | 位置 | 状态 |
|---|---|---|
| Flutter V2 规划仓库 | `C:\Users\Poplar\Desktop\KINGCLUB-APP-V2` | 已确认事实 |
| KingClub 旧客户端 | `C:\Users\Poplar\Desktop\KingClub-app` | `master / 505d222 / 1.1.37`，审计时干净 |
| 新服务端底座 | `C:\Users\Poplar\Desktop\株洲建宁管家\ccsop-service` | `main / f543854`，审计时与远程一致 |
| 旧数据库结构 | `C:\Users\Poplar\Desktop\datebase\nuggets-仅结构.sql` | 仅结构文件，包含 94 张 `k_` 表 |

## 2. 已确认事实

### 旧系统

- 旧 Flutter 前身实际是原生小程序/多端容器工程，不存在可信用户会话。
- 旧客户端通过 `/supper_interface` 明文提交 `interfaceId + params`，所有用户共享硬编码 Basic Authorization。
- 稳定版源码中发现 79 个静态 `S231...` 接口编号，另有普通 HTTP、上传、支付和动态接口调用。
- 手机验证码登录/注册入口使用 `S231202502210650`；客户端把返回的用户资料保存为 `preUserInfo`，没有 access token、refresh token 或服务端会话。
- 旧 WebSocket 使用账号、手机号、时间戳的 MD5 派生签名，消息为明文 JSON。
- 旧数据库包含 94 张 `k_` 表、1,484 个字段，没有数据库外键；大量关系依赖字符串 ID、CSV/LongText 和应用约定。

### 新服务端底座

- 技术栈为 Node.js 24、TypeScript、Express 5、MySQL 8.4、Redis 7.4、BullMQ 和 `ws`。
- 对外统一入口是 `/supper-interface`，支持数据库 Routine 与 adapter 执行器。
- 已实现 ECDH P-256 握手、AES-256-GCM、HKDF-SHA256、HMAC-SHA256、timestamp/nonce/requestId 防重放。
- 已存在 `userAccount`、`userLoginIdentity`、`userProfile`、`userKyc`、`userApiKey`、`authSession` 等身份基础表。
- 已实现会话 touch、revoke、rotate；尚未实现完整的短信挑战、登录/注册、登录成功发证和 refresh token 刷新闭环。
- WebSocket 已支持会话签名、双向密文、消息序号、频道授权、通知确认和通用业务事件队列，但不是完整聊天服务。
- 当前只注册 `zhuzhou-property` 业务线；KingClub 业务线尚未注册。

## 3. 当前阻塞项

1. `interfaceKey` 和 `interfaceReturn` 已从数据库读取，但当前执行链没有实际调用参数校验器。
2. `authPolicy=session` 只验证存在活动会话，没有角色、scope、对象级权限。
3. 数据库 Routine 当前只收到客户端 `params`，没有服务端注入的可信 `userAccount/sessionId/requestId`；继续沿用会允许客户端伪造账号。
4. 新服务端没有完成短信验证码存储、尝试次数、登录发证、refresh token 消费和账号注册事务。
5. 新服务端的 `interface` 元数据查询未按 `businessLine` 过滤；同库部署多业务线存在编号和权限边界风险。
6. 旧 Routine 接收多个标量参数，而新 `db_routine` 执行器只传入一个 JSON 参数，不能直接搬迁。
7. 旧 `s_interface`、`k_user`、`g_sms` 与新 `interface`、统一身份表不是同一模型。
8. WebSocket 当前允许一个会话存在多个连接，尚未定义 KingClub 的重复登录、消息补偿、游标和聊天幂等规则。

## 4. 当前建议的目标结构

```text
Flutter V2
  |-- POST /supper-handshake
  |-- POST /supper-interface -------- 登录前/登录后统一密文业务入口
  |-- POST /auth/session/* ----------- 轮换、注销、刷新会话
  `-- WSS /ws ------------------------ 实时通知和聊天事件
             |
             v
ccsop-service + kingclub business line
  |-- trusted request context
  |-- interface metadata + permission policy
  |-- db_routine / adapter
  |-- Redis replay, login challenge, queue, pub/sub
  |-- internal identity client ----------------------┐
  |                                                  v
  |                                      property public identity
  |                                      |-- U... userAccount authority
  |                                      |-- login identity / KYC summary
  |                                      `-- identity Outbox
  `-- MySQL 8.4 KingClub V2 database
        |-- U... account projection + KingClub session
        |-- kingclub member/domain tables
        `-- identity Inbox + legacy mapping/audit
```

- **已确认事实**：KingClub V2 使用独立服务实例和独立 MySQL 8.4 数据库，先执行服务端底座 migration，再添加 KingClub 业务 migration。
- **当前建议**：旧库保持只读迁移源，不在旧 `k_` 表上直接进行 V2 演进。
- **当前建议**：KingClub 新接口使用独立命名空间，例如 `K + 数字`；旧 `S231...` 只作为兼容映射，不作为 V2 业务语义。
- **当前建议**：WebSocket 只承载实时提示和事件，聊天记录与最终状态以数据库/API 为准。

## 4.1 已确认的部署与分支决策

- **已确认事实**：KingClub 与株洲物业部署在同一台服务器上，但使用独立服务实例、独立数据库、独立数据库账号、独立环境变量、独立 Redis 命名空间、独立日志和独立发布流程。
- **已确认事实**：已部署物业分支为 `business/zhuzhou-property-regulation-v1`；KingClub 不在该分支继续开发。
- **已确认事实**：KingClub 服务端使用从公版 `main / f543854` 创建的 `business/kingclub-v2` 分支。
- **已确认事实**：物业分支和 `JNGJ-WX` 中成熟的握手、登录发证、会话恢复、WebSocket、测试向量和安全日志方案作为迁移依据；不整体合并物业业务代码。
- **已确认事实**：KingClub 同一账号在 KingClub App 内只允许一个活动设备会话，不跨 App 互相踢下线。
- **已确认事实**：KingClub 创建全新接口和 Routine，旧 `S231...` 接口仅用于还原业务语义，不复用编号和实现。

## 4.2 已确认的统一账号方向

- **已确认事实**：KingClub 复用物业公版用户体系的表结构、字段语义和安全规则，并在此基础上扩展。
- **已确认事实**：物业与 KingClub 用户都属于同城用户，目标是未来形成统一用户系统。
- **已确认事实**：第一期不单独建设中央身份服务，物业数据库中的公共用户体系暂时作为统一账号权威源。
- **已确认事实**：统一用户编号继续使用 `userAccount = U + 数字`，KingClub 不创建 `K...` 用户编号，也不新增 `personId`。
- **已确认事实**：KingClub 首次注册通过受保护的服务端内部身份接口查询或创建 `U...`，并在物业公共用户表写入账号、手机号登录身份和真实状态的实名占位/摘要。
- **已确认事实**：该占位不创建物业成员、房屋关系、物业角色或物业权限；用户以后注册物业时复用同一 `U...`，再创建物业业务数据。
- **当前建议**：KingClub 独立库保存相同 `userAccount` 的本地账号投影、KingClub 成员、会话和业务数据；物业公共身份表仍是账号编号、手机号绑定和账号归并的权威源。
- **当前建议**：未来可把这部分公共身份能力从物业实例抽离，两个 App 的 `userAccount` 无需迁号。

## 5. 第一阶段工作包

1. [数据库重建与迁移](../features/foundation/feature_database_rebuild/README.md)
2. [超级接口可信调用链](../features/foundation/feature_super_interface/README.md)
3. [登录、鉴权与会话](../features/identity/feature_login_session/README.md)
4. [WebSocket 实时传输](../features/messaging/feature_realtime_transport/README.md)
5. [同城统一账号](../features/identity/feature_unified_city_identity/README.md)

四个工作包都通过评审和验收前，不开始 Flutter 登录页或业务页面开发。

## 6. 待用户决策

1. Flutter 后续是否增加原生微信授权；第一批后台契约先按手机号短信登录设计。
2. 同一 KingClub 账号在新设备登录前是否增加提示；安全撤销仍建议登录成功后立即生效。
3. KingClub 已核验的姓名/证件信息允许向物业权威库写入哪些字段、使用目的和保留期；未核验数据只允许写真实状态占位。
4. 旧聊天记录、钱包余额、金币、订单与实名资料分别需要迁移多少历史范围。
