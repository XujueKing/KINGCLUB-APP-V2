# KingClub V2 用户数据库表结构草案 V1

- 文档状态：In Review
- 适用阶段：数据库 migration 编写前评审
- 部署边界：物业账号权威库 + KingClub 独立业务库

## 1. 已确认原则

- **已确认事实**：第一期不建设独立中央身份服务，物业公共用户体系暂时作为统一账号权威源。
- **已确认事实**：统一用户编号继续使用 `userAccount = U + 数字`；KingClub 不生成 `K...` 用户编号，也不使用 `personId/UUIDv7`。
- **已确认事实**：KingClub 先注册时，物业权威库必须创建账号、手机号登录身份以及符合真实核验状态的实名占位/摘要。
- **已确认事实**：占位用户不自动成为物业成员，不拥有房屋关系、角色、菜单或物业业务权限。
- **已确认事实**：KingClub 同一 `userAccount` 在 `clientAppCode=kingclub` 范围内只允许一个活动设备会话。

## 2. 物业账号权威库写入

KingClub 首次注册通过内部身份接口原子写入或复用：

| 表 | 写入内容 | 权威性 |
|---|---|---|
| `userAccount` | 新 `U...`、账号状态、来源为 kingclub | 统一编号和账号状态权威 |
| `userLoginIdentity` | 已验证手机号的 HMAC 指纹、密文、验证时间 | 登录身份绑定权威 |
| `userProfile` | 仅必要的最小展示占位 | 公共资料摘要 |
| `userKyc` | anonymous/pending/verified 的真实状态、来源、目的和有效期 | KYC 状态权威 |
| `userKycDocument` | 仅在合法必要且已授权时写材料引用 | 高敏受控数据 |
| `platformAuditLog` | 来源 App、幂等键、结果和 traceId | 安全审计 |

不得写入物业房屋、住户关系、物业会员、组织角色、收费账户或菜单权限表。

## 3. KingClub 独立库模型

### 3.1 `userAccount` 本地投影

为兼容 CCSOP 会话和业务表，KingClub 库保存同一个 `U...`：

| 字段 | 说明 |
|---|---|
| `userAccount` | 物业权威源返回的统一编号，本库禁止生成 |
| `accountStatus` | 最近同步的账号状态摘要 |
| `kycStatus` | 最近同步的 KYC 摘要 |
| `identityVersion` | 权威身份版本，用于拒绝乱序事件 |
| `authoritySource` | 固定为 property_identity_v1 |
| `lastSyncedDate` | 最近同步时间 |
| `createdDate` / `updatedDate` | 标准审计时间 |

### 3.2 `kingclubMember`

以 `userAccount` 作为 KingClub 用户主 ID，不再创建第二套成员 ID。

| 字段 | 类型建议 | 规则 |
|---|---|---|
| `userAccount` | varchar(64) | 主业务关联键，`U...` |
| `memberStatus` | varchar(32) | pending/active/suspended/rejected/closed |
| `joinSource` | varchar(32) | new_register/legacy_migration/invite/admin |
| `joinedDate` | datetime(3) | 首次加入时间 |
| `closedDate` | datetime(3) null | 关闭时间 |
| `createdDate` / `updatedDate` | datetime(3) | 标准审计时间 |

### 3.3 `kingclubProfile`

以 `userAccount` 唯一关联，只保存 KingClub 昵称、头像、城市、兴趣、资料审核状态和资料版本。手机号、证件原值、钱包、订单和权限不得放入本表。

### 3.4 `legacyIdentityMap`

保存 `sourceSystem + sourceEntityType + legacyEntityId -> U... userAccount`。同一旧账号出现冲突时进入人工处理，不覆盖现有映射。

### 3.5 `identityProvisioningAttempt`

记录 KingClub 首次注册跨服务步骤：`provisioningId`、幂等键、手机号指纹、权威 `userAccount`、authorityStatus、memberStatus、重试次数、错误码和时间。不得记录手机号或证件明文。

### 3.6 `identitySyncInbox`

接收权威身份事件：账号冻结/恢复、账号归并、手机号绑定变化、KYC 摘要变化和账号删除。使用 `eventId` 唯一键、`identityVersion` 防乱序，并记录处理状态。

### 3.7 其他第一批表

- `consentRecord`：协议版本、目的、同意/撤回证据。
- `deviceRegistration`：设备实例、推送绑定和风险摘要。
- `smsProvider`、`smsSceneRoute`、`smsVerificationChallenge`、`smsSendAudit`：KingClub 短信挑战和审计。
- `migrationRun`、`migrationError`、`migrationReconciliation`：旧库迁移治理。

## 4. 会话表扩展

### `authSession`

- 保留 `clientAppCode=kingclub`。
- 增加 Refresh Token 当前/上一版本和轮换时间。
- 活动会话生成唯一键 `userAccount|clientAppCode`，确保 KingClub 单设备。
- `revokeReason` 增加 `new_device_login`、`refresh_reuse_detected`、`account_frozen` 和 `identity_merged`。

### `userApiKey`

活动范围为 `userAccount|clientAppCode`。新设备登录事务先撤销旧 Key，再签发新 Key。API Key ID 前缀继续遵守 CCSOP 凭据命名，与 `U... userAccount` 不冲突。

## 5. 首次注册一致性流程

1. KingClub 验证短信挑战并取得服务端可信手机号。
2. 使用唯一幂等键调用物业公共身份接口。
3. 权威库按手机号身份加锁：存在则返回原 `U...`，不存在则生成 `U...` 并写账号、手机号和实名状态占位。
4. 权威库提交后返回 `userAccount` 和身份版本。
5. KingClub 本地事务 upsert 账号投影、创建 `kingclubMember`、撤销旧 KingClub 会话并签发新会话。
6. KingClub 步骤失败时使用原幂等键重试；物业侧孤立占位允许存在，但不得重复发号。

## 6. 物业后续注册流程

1. 物业验证手机号或其他登录身份。
2. 权威身份模块找到 KingClub 已创建的 `U...`。
3. 检查账号状态与身份冲突，不创建第二个用户。
4. 根据业务目的判断现有 KYC 是否可复用；不可复用或已过期则重新核验。
5. 创建物业成员、房屋关系和物业权限，保留来源与审计。

## 7. 实名占位规则

- 没有完成实名核验时只能写 `anonymous` 或 `pending`，不能写 verified。
- 已完成核验时保存核验渠道、引用、时间、有效期和必要摘要；姓名/证件号按字段级加密和目的限制保存。
- 人脸、证件图片默认不因 KingClub 注册复制到物业库，除非有明确合法目的、授权和留存期。
- 物业注册时不得仅因存在占位就自动授予房屋或物业权限。

## 8. migration 开发准入

- [ ] 内部身份接口的服务间鉴权、幂等和超时已评审
- [ ] `U...` 发号并发唯一性与重复手机号冲突测试已评审
- [ ] 权威库占位字段、KYC 状态和数据授权已评审
- [ ] KingClub 本地投影、成员表和身份事件 Inbox 已评审
- [ ] 表/Routine/接口目录登记与双语 COMMENT 已准备
- [ ] 旧 `k_user` 到 `U...` 的冲突处理已评审
- [ ] 文档状态更新为 Approved for Development
