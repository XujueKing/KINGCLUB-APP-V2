# 第一阶段：数据库、超级接口、登录鉴权与 WebSocket

- 文档状态：In Progress
- 审计日期：2026-08-24
- 当前范围：KingClub 登录/会话密文主链、异常矩阵和四个 Flutter 登录页面文档已完成，进入 Flutter Foundation 详细评审；旧客户端和旧数据库仍保持只读

## 1. 输入资产

| 资产 | 位置 | 状态 |
|---|---|---|
| Flutter V2 规划仓库 | `C:\Users\Poplar\Desktop\KINGCLUB-APP-V2` | 已确认事实 |
| KingClub 旧客户端 | `C:\Users\Poplar\Desktop\KingClub-app` | `master / 505d222 / 1.1.37`，审计时干净 |
| 新服务端底座 | `C:\Users\Poplar\Desktop\株洲建宁管家\ccsop-service` | `business/kingclub-v2 / d9929ff`，已推送 |
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
- 已实现 KingClub 短信挑战、登录/注册发证、Refresh Token 轮换/重用检测、会话查询、注销和撤销其他会话闭环。
- WebSocket 已支持会话签名、双向密文、消息序号、频道授权、通知确认和通用业务事件队列，但不是完整聊天服务。
- 已注册 `kingclub` 业务线并将独立实例默认接口命名空间限制为 `K`。

## 3. 当前剩余验收项

1. 生产短信供应商、已审核模板、独立密钥、正式用户协议和隐私政策版本尚未配置。
2. `authPolicy=session` 的通用角色、scope 和对象级权限仍需在进入业务接口前扩展；第一批会话接口已使用可信上下文和专用执行器收口。
3. 聊天消息补偿、游标和业务幂等不属于登录闭环，仍在 WebSocket/消息工作包中待设计。

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

## 4.3 当前实现进度

- **已确认事实**：物业功能分支已实现内部身份超级接口 `S260824000401`、专用服务凭据、幂等供应、身份 Outbox 和 KYC 真实状态规则。
- **已确认事实**：KingClub `business/kingclub-v2` 已完成物业身份加密调用端、migration `018`、本地 `kingclubMember`/供应尝试投影和补偿编排。
- **已确认事实**：KingClub migration `001`～`022` 与物业 migration `001`～`327` 已在隔离 MySQL 8.4 环境真实迁移；A033 幂等、并发、补偿和合成 KYC 冲突联调通过。
- **已确认事实**：[登录、鉴权与会话](../features/identity/feature_login_session/README.md)和[第一批超级接口契约](../features/foundation/feature_super_interface/interface_contracts_v1.md)已批准开发。
- **已确认事实**：migration `019` 已完成短信挑战、本地登录身份投影、协议/同意、设备登记和会话时效基础；空白 MySQL 8.4 从 `001`～`019` 完整实迁通过。
- **已确认事实**：服务端 `business/kingclub-v2 / d9929ff` 已完成 migration `020～022`、短信 Router、七个 `K...` 接口、五个 Routine、协议目录完整性校验和 WebSocket 撤销关闭；本地 `kingclub_v2` 已实迁至 022。
- **已确认事实**：KingClub 37 个测试文件/133 项测试、物业 190 个测试文件/656 项测试及两边完整质量门禁通过；验证码/限流、Refresh Token 重用、协议摘要失败关闭、真实 WebSocket 撤销观测和 KYC 冲突均已完成。
- **已确认事实**：启动鉴权、手机号登录、验证码和协议确认四个首批页面规格均已批准。
- **已确认事实**：验证码页采用 K102 结果未知时失败关闭；协议确认页采用本地 ConsentSnapshot、由 K102 最终落库。
- **已确认事实**：ADR-0001 已批准，本机已升级至 Flutter `3.47.1 stable / Dart 3.13.1`；Android API 24、iOS 15 与核心依赖基线已冻结。
- **已确认事实**：Flutter app_bootstrap 已达到 `Approved for Development`。
- **当前状态**：navigation、App Shell/信息架构和 Design System v1 已完成并处于 `In Review`；networking、session/persistence、observability、Mock Runtime 和原生能力仍待完善或评审。
- **当前建议**：先确认全局导航、四主目的地 + 中央扫码和深色主题方案，再逐个完成剩余 foundation 详细流程和数据契约；foundation 全部批准仅完成底座文档门禁，仍须等待本期全部功能、页面和设计系统文档批准后才创建工程骨架。
- **已确认事实**：Flutter 客户端采用“本期全部文档 → 全部 UI Mock → 整 App UI 验收 → 真实接口/SDK 接入”门禁；已完成的服务端契约在 UI 阶段只作为 Fake/Mock 设计依据。
- **待验收**：生产短信/协议/服务凭据、生产容量、生产日志以及后续物业正式注册复用仍未验收。

## 5. 第一阶段工作包

1. [数据库重建与迁移](../features/foundation/feature_database_rebuild/README.md)
2. [超级接口可信调用链](../features/foundation/feature_super_interface/README.md)
3. [登录、鉴权与会话](../features/identity/feature_login_session/README.md)
4. [WebSocket 实时传输](../features/messaging/feature_realtime_transport/README.md)
5. [同城统一账号](../features/identity/feature_unified_city_identity/README.md)

服务端本地开发门禁、四个登录页面文档准入与 app_bootstrap 已通过；其余 Flutter foundation 仍在评审。即使 foundation 全部批准，也要等待本期全部功能/页面文档完成后才开始 UI；UI 全流程验收前不接真实服务。

## 6. 待用户决策

1. Flutter 后续是否增加原生微信授权；第一批后台契约先按手机号短信登录设计。
2. 旧聊天记录、钱包余额、金币、订单与实名资料分别需要迁移多少历史范围。
