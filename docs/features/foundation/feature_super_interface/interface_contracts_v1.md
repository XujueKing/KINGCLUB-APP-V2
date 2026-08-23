# KingClub V2 第一批超级接口契约

- 文档状态：In Review
- 接口入口：`POST /supper-interface`
- 编号状态：设计预留，尚未写入 `interface` 表
- 业务线：`kingclub`

## 1. 编号与分类建议

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

## 3. `K260824000101` auth.sms.send

请求：

```json
{
  "mobile": "normalized by server",
  "scene": "login",
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

规则：业务线来自部署配置；`clientAppCode` 必须命中允许列表；手机号、设备、IP 和场景多维限流；相同幂等键不得重复发送短信。

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
  "membership": { "appMembershipId": "opaque", "status": "active" },
  "isNewAccount": false,
  "isNewMembership": false
}
```

挑战验证、账号/成员创建、旧 KingClub 会话撤销、新凭据签发和协议记录必须处于同一事务。

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
  "membership": { "appMembershipId": "opaque", "status": "active", "profileVersion": 1 },
  "session": { "sessionId": "opaque", "expiresAt": "ISO-8601" }
}
```

不返回手机号、证件材料、API Key、Refresh Token 或内部 `personId`。

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
  "recentAuthChallengeId": "opaque"
}
```

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

## 11. 登记和测试准入

- [ ] `interfaceKey` 和 `interfaceReturn` 已转换为 CCSOP 紧凑契约并由运行时实际校验
- [ ] `interface_type`、`interface_type_relation` 和六个接口完整登记
- [ ] 执行器、Routine、目录和 sourceMigration 一致
- [ ] 正常、参数错误、权限拒绝、重放、限流、并发和单设备场景均有测试
- [ ] 接口编号在 migration 评审后正式冻结
- [ ] 文档状态更新为 Approved for Development
