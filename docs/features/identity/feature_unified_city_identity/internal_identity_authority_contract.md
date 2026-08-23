# 物业统一账号权威接口契约 V1

- 文档状态：Approved for Development
- 调用方：KingClub 服务端
- 提供方：物业实例中的公共身份模块
- 客户端可见性：禁止 Flutter、小程序和公网普通客户端调用

## 1. 源码审计事实

- **已确认事实**：物业分支通过 `idSequence` 和 `getGenerateId('U')` 原子生成 12 位 `U + 11 位数字` 用户编号。
- **已确认事实**：手机号活动绑定键为 `platform||mobile|{identityValueHash}`；`providerAppCode` 为 null 时手机号在公共身份范围全局唯一。
- **已确认事实**：现有手机号登录 Routine 已能在事务内查找/创建 `userAccount`、`userProfile` 和 `userLoginIdentity`，但同时签发本数据库 Session，不适合作为跨库统一账号接口直接复用。
- **已确认事实**：`userAccount` 目前没有 `originAppCode`、`identityVersion` 或统一身份事件版本。
- **已确认事实**：`userKyc` 只允许 verified 记录成为 current；`userKyc`/`userKycDocument` 没有来源 App 和使用目的字段。
- **已确认事实**：服务端识别 `authPolicy=system`，但当前 HTTP 路由没有任何方式创建 `authMode=system`；仅登记 system 接口会导致所有请求被拒绝。
- **已确认事实**：现有通用消息中心 Outbox 面向通知投递，不是统一身份事实事件 Outbox。

## 2. 接口语义

语义名：`identity.account.resolve_or_create`

接口编号：待物业功能分支 migration 评审后分配。它属于平台内部身份接口，不占用 KingClub `K...` 客户端接口命名空间。

入口继续使用 `POST /supper-interface`，但必须先增加专用服务凭据认证模式。

## 3. 服务间认证

### 请求头

```text
x-service-key-id
x-timestamp
x-nonce
x-request-id
x-trace-id
```

请求体继续使用 CCSOP 的 AES-256-GCM 密文和 HMAC-SHA256 签名。密钥派生保留 HKDF-SHA256，但 domain separation 使用 `ccsop:service-interface:*`，不得与用户 API Key 共用。

### 服务凭据要求

- 新建受控服务凭据，调用方固定为 `kingclub-service`，目标业务线固定为物业公共身份模块。
- 凭据密文保存、支持版本、启停、到期和轮换；不写入 Git 或 migration seed。
- 认证成功后服务端上下文包含 `authMode=system`、`serviceClientId`、`sourceBusinessLine=kingclub`。
- 使用 Redis 校验 timestamp、nonce 和 requestId 防重放。
- 生产环境同时限制内网来源、反向代理链和接口允许列表；IP 允许列表不是唯一认证手段。

## 4. 请求契约

```json
{
  "idempotencyKey": "opaque-32-to-128",
  "sourceAppCode": "kingclub",
  "identity": {
    "type": "mobile",
    "normalizedMobile": "inside encrypted payload",
    "verificationMethod": "sms",
    "verificationId": "opaque",
    "verifiedAt": "ISO-8601"
  },
  "kycClaim": {
    "status": "anonymous|pending|verified",
    "kycType": "cn_id_card|null",
    "verificationProvider": "approved-provider|null",
    "providerReference": "opaque|null",
    "verifiedAt": "ISO-8601|null",
    "expiresAt": "ISO-8601|null",
    "realName": "inside encrypted payload or null",
    "documentType": "cn_id_card|null",
    "documentNo": "inside encrypted payload or null",
    "retentionUntil": "ISO-8601|null",
    "consentRecordId": "opaque|null"
  }
}
```

### 字段规则

- `sourceAppCode` 从服务凭据允许范围复核，不能只信请求字段。
- `normalizedMobile` 只存在于已加密载荷和过程内存；物业模块使用自己的 HMAC/加密密钥生成检索指纹和密文。
- `verificationId` 必须在 `kingclub + sms` 范围唯一，并进入审计；它证明 KingClub 服务已验证控制权，不允许客户端自报。
- `anonymous` 不允许携带姓名和证件号。
- `pending` 不得设置 verifiedDate，也不得创建 current KYC。
- `verified` 必须提供受支持核验方、引用、核验时间、单独授权证据和必要实名字段。
- 原始证件图片、人脸照片和活体视频不属于 V1 请求。

## 5. 权威库事务

1. 按 `serviceClientId + sourceAppCode + idempotencyKey` 查询幂等记录并加锁；已完成则返回原结果。
2. 规范化手机号，在物业实例内生成 `identityValueHash` 和 `identityValueEncrypted`。
3. 按手机号活动绑定唯一键查询并加锁。
4. 已存在账号时处理 merged 指向，检查 active 状态并返回保留账号。
5. 不存在时调用 `getGenerateId('U')`，创建 `userAccount`、空 `userProfile` 和已验证的 mobile `userLoginIdentity`。
6. 写入 `originAppCode=kingclub` 和递增 `identityVersion`。
7. 根据 `kycClaim` 写真实状态：anonymous 只更新账号摘要；pending 建非 current 记录；verified 经冲突检查后写 KYC/Document。
8. 写 provisioning 结果、安全审计和身份 Outbox。
9. 提交事务并返回；不创建物业成员、房屋关系、角色或权限。

## 6. 已有账号与 KYC 冲突规则

- 现有 verified KYC 不会被 anonymous/pending 降级或覆盖。
- 相同证件指纹已属于其他活动账号时返回冲突，不自动合并。
- KingClub 的 verified 信息与现有 verified 信息不一致时进入人工处理。
- 账号已 merged 时返回最终保留 `userAccount` 和最新 `identityVersion`。
- 账号 disabled/deleted 时不允许 KingClub 创建新账号绕过状态。

## 7. 响应契约

```json
{
  "userAccount": "U00000000001",
  "isNewAccount": true,
  "accountStatus": "active",
  "kycStatus": "anonymous",
  "identityVersion": 1,
  "provisioningStatus": "created|resolved|manual_review"
}
```

不返回手机号、姓名、证件号、权威库内部 rowId 或物业业务数据。

## 8. 错误契约

| 错误码 | HTTP | 是否重试 | 含义 |
|---|---:|---|---|
| `SERVICE_AUTH_REQUIRED` | 401/403 | 否 | 服务凭据缺失或无权调用 |
| `SERVICE_REQUEST_REPLAYED` | 409 | 否 | nonce/requestId 已使用 |
| `IDENTITY_INPUT_INVALID` | 400 | 否 | 身份或 KYC 字段不合法 |
| `IDENTITY_MOBILE_CONFLICT` | 409 | 否 | 手机号活动绑定冲突 |
| `IDENTITY_KYC_CONFLICT` | 409 | 否 | 实名信息与其他账号冲突 |
| `IDENTITY_ACCOUNT_DISABLED` | 403 | 否 | 权威账号不可用 |
| `IDENTITY_MANUAL_REVIEW_REQUIRED` | 409 | 否 | 需要人工核对或归并 |
| `IDENTITY_AUTHORITY_BUSY` | 503 | 是 | 锁竞争或权威服务暂不可用 |
| `IDENTITY_IDEMPOTENCY_MISMATCH` | 409 | 否 | 同一幂等键对应了不同请求摘要 |

## 9. 幂等与补偿

- 幂等记录保存请求摘要、统一账号、结果、状态、首次/最近尝试时间和 traceId，不保存敏感原值。
- 相同幂等键和相同请求摘要返回相同 `userAccount`。
- 相同幂等键但请求摘要不同直接拒绝。
- 物业事务成功、KingClub 本地事务失败时，KingClub 重试原幂等键；权威库占位不回滚、不重复发号。
- KingClub 不得在超时后自行创建 `U...`；超时重试仍使用原幂等键。

## 10. 验收

- [ ] 当前不存在的手机号并发请求只创建一个 `U...`
- [ ] 已存在手机号返回原账号，不新增 `userAccount`
- [ ] 相同幂等键重试结果完全一致
- [ ] system 服务凭据、加密、签名和防重放测试通过
- [ ] anonymous/pending 不会生成 verified/current KYC
- [ ] verified KYC 冲突不会被覆盖
- [ ] 占位账号没有任何物业业务权限
- [ ] 审计和日志不包含手机号、姓名、证件号或服务密钥

## 11. 开发批准记录

- **已确认事实**：2026-08-24 用户同意采用专用服务凭据、加密超级接口和本契约默认 KYC 最小化方案，并进入下一步开发。
- **已确认事实**：V1 不传身份证图片、人脸照片或活体视频。
- **已确认事实**：只有真实核验通过的实名信息才能写 verified；未核验数据只写 anonymous/pending。
