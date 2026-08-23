# KingClub V2 第一批超级接口契约

- 文档状态：Approved for Development
- 接口入口：`POST /supper-interface`
- 编号状态：V1 已冻结，migration 020 已写入 `interface` 表
- 业务线：`kingclub`

## 1. V1 编号与分类

| interfaceId | 语义名 | 鉴权 | 写操作 |
|---|---|---|---|
| `K260824000100` | 身份与会话分类节点 | - | - |
| `K260824000101` | `auth.sms.send` | handshake | 是 |
| `K260824000102` | `auth.sms.login` | handshake | 是 |
| `K260824000103` | `auth.session.refresh` | handshake + refresh credential | 是 |
| `K260824000104` | `auth.session.me` | session | 否 |
| `K260824000105` | `auth.session.logout` | session | 是 |
| `K260824000106` | `auth.session.revoke_others` | session + recent auth | 是 |

编号只用于 CCSOP 元数据和 SDK 注册。Flutter 页面、Widget、ViewModel 与业务 UseCase 只调用语义方法。

## 2. 公共可信上下文

执行器传给 Routine 的根对象由服务端构造：

```json
{
  "params": {},
  "auth": {
    "userAccount": "from verified session",
    "sessionId": "from verified session",
    "apiKeyId": "from verified session",
    "businessLine": "kingclub",
    "clientAppCode": "kingclub"
  },
  "request": {
    "requestId": "verified request id",
    "traceId": "server trace id",
    "ipAddress": "trusted transport context"
  }
}
```

握手接口没有 userAccount。客户端参数出现 `auth`、`request`、`userAccount`、角色或权限字段时直接拒绝。

## 2.1 服务间统一账号接口

KingClub 短信登录执行器在挑战验证成功后调用物业公共身份模块的 `identity.account.resolve_or_create`。该接口不属于 Flutter 的 `K...` 接口，不暴露公网普通客户端，具体 interfaceId 由物业身份迁移评审后登记。

字段级契约、system 服务凭据缺口、权威库事务和错误码见[物业统一账号权威接口契约 V1](../../identity/feature_unified_city_identity/internal_identity_authority_contract.md)。

输入包含服务端已验证手机号、验证证据、真实 KYC 状态/来源、`sourceAppCode=kingclub` 和幂等键。权威库按手机号活动绑定加锁：存在则返回原 `U...`，不存在则原子创建账号、手机号登录身份和 KYC 占位/摘要。

响应至少包含：

```json
{
  "userAccount": "U...",
  "isNewAccount": true,
  "accountStatus": "active",
  "kycStatus": "anonymous|pending|verified",
  "identityVersion": 1
}
```

服务间接口必须使用独立凭据、加密载荷、来源允许列表、短超时、幂等、审计和限流。KingClub 不得直接写物业数据库表，也不得在该接口失败时自行生成 `U...`。

## 3. `K260824000101` auth.sms.send

请求：

```json
{
  "mobile": "normalized by server",
  "scene": "login|recent_auth",
  "clientAppCode": "kingclub",
  "clientType": "android|ios",
  "deviceId": "opaque-device-id"
}
```

响应：

```json
{
  "challengeId": "opaque",
  "expiresInSeconds": 300,
  "retryAfterSeconds": 60,
  "maskedMobile": "***"
}
```

规则：业务线来自部署配置；`clientAppCode` 必须命中允许列表；V1 场景只允许 `login` 和 `recent_auth`；手机号、设备、IP 和场景多维限流；相同幂等键不得重复发送短信。接口对号码是否已注册返回相同外观，避免账号枚举。

## 4. `K260824000102` auth.sms.login

请求：

```json
{
  "challengeId": "opaque",
  "mobile": "user input",
  "code": "user input",
  "clientAppCode": "kingclub",
  "clientType": "android|ios",
  "deviceId": "opaque-device-id",
  "consents": [
    { "agreementCode": "terms", "version": "published-version" },
    { "agreementCode": "privacy", "version": "published-version" }
  ]
}
```

响应仅在握手密文中返回一次：

```json
{
  "sessionId": "opaque",
  "apiKeyId": "opaque",
  "apiKey": "one-time-secret",
  "refreshToken": "one-time-secret",
  "refreshTokenVersion": 1,
  "expiresAt": "ISO-8601",
  "refreshExpiresAt": "ISO-8601",
  "account": { "userAccount": "opaque", "accountStatus": "active" },
  "membership": { "status": "active" },
  "isNewAccount": false,
  "isNewMembership": false
}
```

物业权威库的账号写入和 KingClub 本地事务无法组成数据库分布式事务：验证码先转成短期可消费证明；本地手机号指纹投影未命中时，先登记/复用 provisioning attempt，再在本地事务外幂等取得 `U...`。随后 KingClub 在一个本地事务内消费短信证明、回填非权威手机号指纹投影、创建成员、记录协议、撤销旧会话并签发新凭据。本地失败时使用同一 provisioning 幂等键补偿重试，不回滚物业账号、不重复发号。

## 5. `K260824000103` auth.session.refresh

请求通过新握手密文发送：

```json
{
  "sessionId": "opaque",
  "refreshToken": "current-secret",
  "refreshTokenVersion": 1,
  "clientAppCode": "kingclub",
  "clientType": "android|ios",
  "deviceId": "opaque-device-id"
}
```

响应返回新的 `apiKeyId`、`apiKey`、`refreshToken`、递增版本和两个过期时间。旧 Token 重用时撤销整个会话；并发更新返回可区分的冲突错误，不回传任何凭据。

## 6. `K260824000104` auth.session.me

无业务参数。身份全部来自可信会话上下文。

```json
{
  "account": { "userAccount": "opaque", "accountStatus": "active", "kycStatus": "anonymous" },
  "membership": { "status": "active", "profileVersion": 1 },
  "session": { "sessionId": "opaque", "expiresAt": "ISO-8601" }
}
```

不返回手机号、证件材料、API Key 或 Refresh Token。

## 7. `K260824000105` auth.session.logout

无业务参数，幂等撤销当前可信 Session 与 API Key。重复调用返回同一业务结果，不返回“找不到会话”的可枚举差异。

```json
{
  "revoked": true,
  "revokedAt": "ISO-8601",
  "reason": "logout"
}
```

## 8. `K260824000106` auth.session.revoke_others

请求不允许传 userAccount。默认撤销当前账号在 `clientAppCode=kingclub` 下除当前会话外的所有活动/异常残留会话；执行前要求近期短信验证或其他已批准的 recent-auth 证据。

```json
{
  "recentAuthChallengeId": "opaque",
  "code": "six-digits"
}
```

服务端校验 challenge 的 `scene=recent_auth`，并将其手机号 HMAC 指纹与当前可信账号的活动本地登录身份投影匹配；不允许客户端提交 userAccount 或让 challenge 为其他账号授权。验证码证明和撤销动作在同一事务边界内单次消费。

响应：`revokedCount`、`revokedAt`。每个被撤销会话发布 `auth.session.revoked`。

## 9. WebSocket 鉴权与撤销事件

WebSocket 继续使用 `apiKeyId + sessionId + timestamp + nonce + requestId + clientId + sign` 建连，服务端必须验证：

- API Key 和 Session 均为 active，且归属同一账号和 KingClub App。
- timestamp 窗口、nonce/requestId 防重放、签名和 clientId 哈希。
- 连接注册在 sessionId 索引下，便于单设备顶号后跨实例关闭。

服务端事件 `auth.session.revoked` 包含 sessionId、原因和撤销时间。它是即时通知；最终权限以数据库/API 会话状态为准。

## 10. 第一批错误码

| 错误码 | HTTP 建议 | 含义 |
|---|---:|---|
| `AUTH_SMS_RATE_LIMITED` | 429 | 短信发送过于频繁 |
| `AUTH_CHALLENGE_INVALID` | 400 | 挑战、手机号或场景不匹配 |
| `AUTH_CHALLENGE_EXPIRED` | 410 | 挑战已过期 |
| `AUTH_CHALLENGE_LOCKED` | 423 | 尝试次数达到上限 |
| `AUTH_CODE_INVALID` | 401 | 验证码错误 |
| `AUTH_ACCOUNT_DISABLED` | 403 | 平台账号不可登录 |
| `AUTH_MEMBERSHIP_RESTRICTED` | 403 | KingClub 成员状态受限 |
| `AUTH_SESSION_REVOKED` | 401 | 会话已撤销 |
| `AUTH_REFRESH_TOKEN_INVALID` | 401 | Refresh Token 无效 |
| `AUTH_REFRESH_REUSE_DETECTED` | 401 | 检测到旧 Token 重用并已撤销 |
| `AUTH_REFRESH_CONCURRENT_UPDATE` | 409 | 另一个刷新事务已成功 |
| `AUTH_RECENT_VERIFICATION_REQUIRED` | 403 | 高风险操作缺少近期验证 |
| `IDENTITY_AUTHORITY_UNAVAILABLE` | 503 | 统一账号权威接口暂时不可用，不允许本地发号 |
| `IDENTITY_BINDING_CONFLICT` | 409 | 手机号或实名身份已绑定到冲突账号 |

## 11. 登记和测试准入

- [x] `interfaceKey` 和 `interfaceReturn` 已转换为 CCSOP 紧凑契约并由运行时实际校验
- [x] `interface_type`、`interface_type_relation` 和六个接口完整登记
- [x] 执行器、Routine、目录和 sourceMigration 一致
- [ ] 正常、参数错误、权限拒绝、重放、限流、并发和单设备场景均有测试
- [x] 接口编号在文档评审后正式冻结
- [x] 服务间统一账号接口、幂等、占位写入和补偿的隔离 A033 测试通过
- [x] 文档状态更新为 Approved for Development

尚未勾选项是实现验收项，不再阻塞 migration 与执行器开发。

实现位置：服务端 `business/kingclub-v2 / c21d9bc`。尚未勾选的自动化矩阵需要通过六个真实密文 HTTP 接口和双服务完整登录链路补齐，不能用 Routine 冒烟代替。
