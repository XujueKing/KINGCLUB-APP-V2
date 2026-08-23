# KingClub V2 用户数据库表结构草案 V1

- 文档状态：In Review
- 适用阶段：数据库 migration 编写前评审
- 部署边界：KingClub 独立 MySQL 8.4 数据库

## 1. 已确认原则

- **已确认事实**：第一期不建设中央身份服务，KingClub 使用独立数据库。
- **已确认事实**：复用 CCSOP 公版用户基础模型，并为未来同城统一用户系统预留稳定标识和映射。
- **已确认事实**：KingClub 同一账号在 `clientAppCode=kingclub` 范围内只允许一个活动设备会话。
- **当前建议**：`personId` 使用 UUIDv7 字符串并保存在 `varchar(64)`；最终编码方案需在 migration 评审时确认。
- **当前建议**：数据库不跨库建立外键；通过唯一索引、事务 Routine、目录登记和一致性测试维护关系。

## 2. 直接复用的公版表

| 表 | 用途 | V1 处理 |
|---|---|---|
| `userAccount` | 平台账号与冻结/归并状态 | 增加 `personId` 索引，不加入 KingClub 资料字段 |
| `userLoginIdentity` | 手机号、微信等登录身份 | 保留 HMAC 指纹与密文值，手机号活动绑定全局唯一 |
| `userProfile` | 最小平台资料 | 只放可跨业务复用的最小资料 |
| `userKyc` / `userKycDocument` | KYC 结果与材料引用 | 第一批不迁移旧明文材料 |
| `userApiKey` | 移动端 API Key | 活动范围改为账号 + App，支持单设备策略 |
| `authSession` | 会话与 Refresh Token | 增加版本、重用检测和 App 单设备唯一键 |
| `userAccountMerge` | 账号归并审计 | 保留，不自动按手机号合并 |
| `platformAuditLog` | 安全与接口审计 | 使用 KingClub 独立业务线和脱敏元数据 |

## 3. V1 新增与扩展表

### 3.1 `personIdentity`

同城自然人的最小内部锚点，不直接返回客户端。

| 字段 | 类型建议 | 规则 |
|---|---|---|
| `rowId` | bigint | 自增内部行号 |
| `personId` | varchar(64) | UUIDv7，全局唯一 |
| `personStatus` | varchar(32) | active/merged/disabled/deleted |
| `mergedToPersonId` | varchar(64) null | 归并目标，仅 merged 时存在 |
| `sourceSystem` | varchar(64) | kingclub_v2/legacy_kingclub/identity_import |
| `createdDate` / `updatedDate` | datetime(3) | 标准审计时间 |

索引：`uk_personIdentity_personId`、`idx_personIdentity_status_created`。

### 3.2 `userAccount` 扩展

新增 `personId varchar(64) NOT NULL`，建立 `idx_userAccount_person_status(personId, accountStatus)`。允许一个自然人因历史冲突临时拥有多个账号，必须通过 `userAccountMerge` 审计归并。

### 3.3 `appMembership`

表示自然人在某个产品内的成员身份，与平台账号状态、KYC 和会员付费状态分离。

| 字段 | 类型建议 | 规则 |
|---|---|---|
| `appMembershipId` | varchar(64) | KingClub 对外成员编号 |
| `personId` | varchar(64) | 内部自然人 |
| `userAccount` | varchar(64) | 当前登录账号 |
| `appCode` | varchar(64) | V1 固定为 kingclub |
| `membershipStatus` | varchar(32) | pending/active/suspended/rejected/closed |
| `joinSource` | varchar(32) | new_register/legacy_migration/invite/admin |
| `joinedDate` | datetime(3) | 首次加入时间 |
| `closedDate` | datetime(3) null | 关闭时间 |
| `createdDate` / `updatedDate` | datetime(3) | 标准审计时间 |

唯一键：`(personId, appCode)`、`(userAccount, appCode)`；一个 KingClub 账号只能对应一个有效成员。

### 3.4 `kingclubProfile`

只保存 KingClub 业务资料：`appMembershipId`、昵称、头像、性别展示策略、生日展示策略、城市、资料审核状态、资料版本和更新时间。实名认证原值、手机号、钱包、金币和权限不得放入本表。

### 3.5 `legacyIdentityMap`

| 字段 | 说明 |
|---|---|
| `mappingId` | 映射记录编号 |
| `sourceSystem` | 固定受控值，例如 legacy_kingclub |
| `sourceEntityType` | user/account/profile 等受控枚举 |
| `legacyEntityId` | 旧记录原始 ID，不作为新主键 |
| `personId` | 新自然人编号 |
| `userAccount` | 新平台账号 |
| `appMembershipId` | 新 App 成员编号 |
| `mappingStatus` | pending/confirmed/conflict/ignored |
| `evidenceHash` | 映射证据摘要，不保存明文证据 |
| `migrationRunId` | 所属迁移批次 |

唯一键：`(sourceSystem, sourceEntityType, legacyEntityId)`；同一旧账号出现冲突时进入人工队列，不覆盖已有映射。

### 3.6 `consentRecord`

记录 `userAccount`、`appMembershipId`、协议编码、协议版本、目的编码、同意/撤回动作、客户端类型、证据摘要、发生时间。登录只接受服务端已发布且仍有效的协议版本。

### 3.7 `deviceRegistration`

保存 App 设备实例和推送绑定：`deviceRegistrationId`、`userAccount`、`appCode`、`deviceIdHash`、平台、推送提供方、推送 Token 密文/指纹、状态、最近登录和最后活跃时间。不得把设备在线状态写入用户主表。

### 3.8 短信基础表

从物业成熟方案迁移以下通用模型，但重新创建 KingClub migration 和目录登记：

- `smsProvider`
- `smsSceneRoute`
- `smsVerificationChallenge`
- `smsSendAudit`

挑战必须保存手机号 HMAC 指纹、验证码哈希、场景、过期时间、最大尝试次数、消费时间和状态；不保存验证码明文。

### 3.9 迁移治理表

- `migrationRun`：来源、范围、开始/结束时间、版本、统计与状态。
- `migrationError`：批次、来源实体、脱敏定位信息、错误码和处理状态。
- `migrationReconciliation`：表/指标、源值、目标值、差异和复核结果。

## 4. 会话表扩展

### `authSession`

新增或确认：

- `clientAppCode`：KingClub App 作用域。
- `refreshTokenVersion`：从 1 单调递增。
- `previousRefreshTokenHash` / `previousRefreshTokenVersion`：识别旧 Token 重用。
- `refreshTokenRotatedDate`：最近轮换时间。
- `activeAppSessionKey`：活动会话时生成 `userAccount|clientAppCode`，其他状态为 null，并建立唯一索引。
- `revokeReason` 增加 `new_device_login`、`refresh_reuse_detected` 和 `account_frozen`。

### `userApiKey`

`activeScopeKey` 的 KingClub V1 语义为 `userAccount|clientAppCode`，不再包含 `deviceId`。新设备登录事务必须先撤销旧 Key，再签发新 Key。

## 5. 登录事务边界

短信登录或注册必须在一个数据库事务内完成：

1. 锁定并验证短信挑战，检查场景、手机号指纹、TTL、尝试次数和消费状态。
2. 查找或创建 `personIdentity`、`userAccount` 和 `userLoginIdentity`。
3. 查找或创建 `appMembership`，检查成员状态。
4. 锁定账号在 KingClub App 下的活动会话并以 `new_device_login` 撤销。
5. 撤销旧 API Key，创建新 API Key、Refresh Token 版本和 `authSession`。
6. 标记挑战 consumed，写协议证据、设备记录和安全审计。
7. 提交后发布旧会话撤销事件；事件失败不能回滚已完成的安全撤销。

## 6. 数据隔离与敏感等级

| 数据 | 默认范围 | 最低保护 |
|---|---|---|
| `personId` | 内部身份域 | 不对客户端暴露 |
| 手机号 | 统一登录身份 | 规范化后 HMAC 检索 + 密文保存 |
| 验证码 | 登录挑战 | 只保存哈希，短 TTL，消费后不可重放 |
| Refresh Token | 会话 | 只保存带上下文哈希 |
| API Key | 会话 | 服务端密文保存，客户端安全存储 |
| 昵称/头像 | KingClub App | 与物业资料默认隔离 |
| KYC 材料 | 受控身份域 | 最小化、加密、留存期和访问审计 |
| 钱包/订单 | KingClub 业务域 | 严格不进入身份表 |

## 7. migration 开发准入

- [ ] UUIDv7 生成位置、库函数或服务端库已评审
- [ ] 所有表字段、索引、状态枚举和双语 COMMENT 已评审
- [ ] 表目录分类和 `databaseCatalogTable` 登记方案已准备
- [ ] Routine 目录与版本方案已准备
- [ ] 单设备唯一索引和并发登录测试已评审
- [ ] 旧 `k_user` 字段映射与冲突样本规则已评审
- [ ] 文档状态更新为 Approved for Development
