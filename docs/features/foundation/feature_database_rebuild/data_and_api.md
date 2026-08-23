# 数据模型与接口影响

## 已确认的统一账号边界

```text
物业公共用户体系（账号权威源）
  userAccount = U...
  userLoginIdentity = 手机号/微信等统一登录身份
  userKyc = 有来源和状态的实名记录或占位
             |
             | 内部身份接口
             v
KingClub 独立数据库
  userAccountProjection = 同一个 U... 的本地投影
  kingclubMember = KingClub 成员状态
  kingclubProfile = KingClub 独立资料
  authSession / userApiKey = KingClub 独立会话
```

- `U... userAccount` 只能由物业公共身份模块生成。
- KingClub 不生成 `K...` 用户编号，也不增加 `personId`。
- KingClub 首次注册成功后，即使用户从未使用物业 App，物业公共用户表中也存在对应账号和登录身份。
- 物业后续注册通过已验证手机号等身份找到该账号，创建物业成员/房屋关系，不再创建第二个用户。

## 第一批复用的公版表

- 物业权威库：`userAccount`、`userLoginIdentity`、`userProfile`、`userKyc` / `userKycDocument`、`userAccountMerge`。
- KingClub 独立库：`userAccount` 本地投影、`userApiKey`、`authSession`、`platformAuditLog`。

KingClub 本地 `userAccount` 行只保存业务运行所需的账号编号、同步状态和安全状态摘要，不成为手机号绑定、账号合并或统一编号的权威来源。

## 第一批新增的 KingClub 数据

| 概念 | 用途 | 状态 |
|---|---|---|
| `kingclubMember` | 以 `userAccount` 为主键关联的 KingClub 成员状态 | 已确认 |
| `kingclubProfile` | KingClub 内昵称、头像和业务资料 | 已确认 |
| `legacyIdentityMap` | 旧 `k_user.userAccount` 到统一 `U...` 的映射 | 已确认 |
| `identitySyncInbox` | 接收账号冻结、归并、手机号变更等身份事件 | 当前建议 |
| `identityProvisioningAttempt` | 跨服务查询/创建账号的幂等与补偿记录 | 当前建议 |
| `loginChallenge` | 验证码哈希、TTL、尝试次数和消费状态 | 采用短信基础表 |
| `consentRecord` | 协议版本、同意时间和目的 | 当前建议 |
| `deviceRegistration` | 设备、推送 Token、最近登录和风险摘要 | 当前建议 |
| `migrationRun` / `migrationError` | 迁移批次、校验和异常 | 当前建议 |

## 关键映射原则

- 旧 `k_user.userAccount` 保留为 `legacyUserAccount`，不直接当新主键。
- 手机号验证成功后，由物业身份接口按统一规范查询或原子创建 `U...`。
- 手机号在权威库保存受控 HMAC 指纹与密文值；KingClub 业务表不复制手机号明文。
- “实名占位”不得伪造 verified：未核验时记录 pending/anonymous；已核验时保存来源、目的、有效期、结果摘要和必要密文，不复制人脸或证件图片。
- `userStatus` 拆为平台账号状态、KYC 状态和 KingClub 成员状态。
- `wsStatus` 不迁移；在线状态由 WebSocket/Redis 计算。
- `registrationId` 进入设备/推送绑定，不放在用户主表。

## 内部身份接口

KingClub 服务不得直接连接并写物业业务表。它调用物业实例内的公共身份模块：

```json
{
  "verifiedIdentity": {
    "type": "mobile",
    "normalizedValue": "server-to-server encrypted",
    "verificationId": "opaque",
    "verifiedAt": "ISO-8601"
  },
  "kycClaim": {
    "status": "anonymous|pending|verified",
    "provider": "kingclub",
    "providerReference": "opaque",
    "expiresAt": "ISO-8601 or null"
  },
  "sourceAppCode": "kingclub",
  "idempotencyKey": "opaque"
}
```

返回 `userAccount`、是否新建、账号状态和 KYC 摘要。接口使用服务间鉴权、加密载荷、允许列表、超时、审计和幂等；客户端不能调用。

## 跨服务一致性

1. 物业身份接口先提交统一账号和占位记录。
2. KingClub 再以同一个 `userAccount` 创建本地投影和 `kingclubMember`。
3. 第二步失败时保留物业侧占位，使用同一幂等键重试；不得创建新的 `U...`。
4. 账号冻结、归并、手机号变更和删除通过 Outbox/事件同步到 KingClub。
5. 属性同步失败进入 `identitySyncInbox` 重试和人工告警，不使用跨数据库分布式事务。

## Routine 可信上下文

新 Routine 统一接收服务端 envelope；客户端不得提交或覆盖 `auth`、`request`、`userAccount`、角色和权限字段。
