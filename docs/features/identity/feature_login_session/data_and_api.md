# 登录数据与接口

## 复用模型与权威来源

- `userAccount`：平台永久统一账号，由物业公共身份模块生成，格式 `U...`
- `userLoginIdentity`：手机号/微信等统一登录标识，物业公共身份模块为权威源
- `userProfile` / `userKyc`：公共资料和真实 KYC 状态占位/摘要，物业公共身份模块为权威源
- `userApiKey`：非 Web 终端 API Key 密文
- `authSession`：登录会话和 refresh token 哈希

## V1 新增模型

- `kingclubMember`：以统一 `userAccount` 关联的 KingClub 成员状态，不与账户冻结/KYC 混用
- `legacyIdentityMap`：旧 `k_user.userAccount` 到统一 `U...` 的映射
- `identityProvisioningAttempt`：跨服务创建/查询统一账号的幂等和补偿状态
- `identitySyncInbox`：账号冻结、归并和 KYC 摘要等权威事件同步
- `loginChallenge`：验证码哈希、场景、TTL、尝试次数、消费时间
- `consentRecord`：协议版本和同意证据
- `deviceRegistration`：设备、推送 token、最近登录和风险摘要
- `kingclubLoginIdentityProjection`：手机号 HMAC 指纹到 `U...` 的本地非权威映射，包含指纹/身份版本和同步状态，不保存手机号明文

## 权威解析与本地登录索引

- 手机号绑定的权威事实仍在物业 `userLoginIdentity`，KingClub 本地表只用于登录解析和跨服务降耦。
- 本地指纹使用 KingClub 独立 HMAC 密钥和版本，禁止复用物业密钥或直接复制物业 `identityValueHash`。
- 指纹活动唯一键为 `identityType + fingerprintVersion + identityFingerprint`；一个活动手机号只能映射一个 `userAccount`。
- 本地命中且身份版本有效时不调用物业接口。未命中时以验证码挑战衍生的稳定幂等键调用 `S260824000401`，成功后在本地事务中回填。
- 权威事件带更高 `identityVersion`、账号冻结或归并时，本地投影按版本幂等更新并撤销受影响 KingClub 会话。

## V1 接口语义

| interfaceId | 语义 | 鉴权 | 幂等/限制 |
|---|---|---|---|
| `K260824000101` | auth.sms.send | handshake | 手机号/设备/IP 限流，同幂等键不重复发送 |
| `K260824000102` | auth.sms.login | handshake | challenge 单次消费，失败次数上限 |
| `K260824000103` | auth.session.refresh | handshake + refresh credential | refresh token 轮换，旧 token 重用检测 |
| `K260824000104` | auth.session.me | session | 返回最小身份与成员状态 |
| `K260824000105` | auth.session.logout | session | 幂等撤销当前会话 |
| `K260824000106` | auth.session.revoke_others | session + recent SMS auth | 不允许传 userAccount，撤销 KingClub 残留会话 |

以上编号在 V1 冻结；详细请求、响应和错误码见[第一批超级接口契约](../../foundation/feature_super_interface/interface_contracts_v1.md)。

## 会话字段与时效

- `authSession.expiresDate` 表示访问会话到期时间，默认签发后 2 小时。
- 新增 `refreshExpiresDate`，默认签发或成功刷新后 30 天；访问会话过期不等于 Refresh Token 可继续调用普通接口。
- Refresh Token 成功使用后生成新的 API Key、Refresh Token 和版本，旧 API Key 立即撤销。
- 客户端在访问会话剩余 10 分钟时 SingleFlight 刷新；服务端 TTL 来自受控配置，客户端以响应时间为准。
- `revokeReason` 增加 `new_device_login`、`refresh_reuse`、`account_disabled` 和 `account_merged`。

## 协议与隐私同意

- 服务端维护可发布协议目录：`agreementCode + version + status + publishedAt + contentDigest`。
- V1 登录至少要求 `terms` 和 `privacy` 两项当前强制版本；客户端提交其展示版本，服务端不替客户端自动补同意。
- `consentRecord` 保存用户、协议、版本、摘要、时间、来源 App、设备摘要和请求审计引用；记录追加写且不可静默覆盖。
- 强制协议升级后，旧会话访问受限业务前进入重新同意流程；该页面需另建功能目录后开发。

## 登录响应最小字段

```json
{
  "sessionId": "...",
  "apiKeyId": "...",
  "apiKey": "...",
  "refreshToken": "...",
  "expiresAt": "...",
  "refreshExpiresAt": "...",
  "user": { "userAccount": "..." },
  "membership": { "status": "..." }
}
```

响应只在 handshake 密文中返回。手机号、证件信息和完整资料不随登录响应重复下发。

## 安全存储

- iOS：Keychain
- Android：Keystore 支持的加密存储
- 禁止普通 SharedPreferences、日志、URL、埋点和崩溃附件包含 apiKey/refreshToken
