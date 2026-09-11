# 登录数据与接口

最新用户纠正：NEXT仅按11位合法手机号+6位数字及非忙碌状态启用，不依赖本地challenge。未获取短信可直接提交K102，省略challengeId；先读取协议目录，不发送短信。后端仅为授权临时固定码匹配创建内部challenge，普通号码/错误码正常拒绝。移除“请先获取验证码”提示，灰色仍用于格式不完整及忙碌状态。此规则覆盖下方历史条件。

## 2026-09-11 NEXT 启用与禁用

NEXT 只有手机号符合大陆11位格式、验证码为6位数字、已取得当前号码challenge且没有请求/校验进行中时启用。禁用时使用明确灰底灰字，与启用金棕色区分；位数齐全但未获取challenge时显示“请先点击获取验证码”。号码修改使旧challenge失效，异步短信结果不得绑定到修改后的号码。固定测试码仍通过同一challenge流程，客户端不验证固定值或绕过服务端。

## 2026-09-11 真实注册分流

用户要求参照旧版：短信验证后，已注册进入首页，未注册进入实名。旧 userStatus=2/1/其他分别对应已通过/待审/未完成；新 kingclubMember.memberStatus=active 只表示未禁用，不代表已注册。后端 migration 024 新增 registrationStatus，K102/K104返回该字段。以 active + approved 进入首页；identity_required进入实名，pending_review进入审核状态；其余进度按状态提示恢复，未知/限制状态不放行。isNewMembership仅为是否本次建档，第二次登录不能据此绕过实名。

真实登录不创建 MockOnboardingSnapshot。现有实名页接收真实会话上下文；腾讯正式上传/核验接口尚未落地时，不能调用 Mock 生成成功，提交应提示服务暂不可用且留在页面。本批交付真实分流与状态刷新，不宣称照片实名完成。旧会员数据尚未迁入，不自动查询或修改旧库。

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
| `K260824000107` | auth.agreements.current | handshake | 返回当前 terms/privacy 受控 Markdown 与摘要，不含身份字段 |

以上编号在 V1 冻结；详细请求、响应和错误码见[第一批超级接口契约](../../foundation/feature_super_interface/interface_contracts_v1.md)。

`K260824000101` 的业务 `idempotencyKey` 与传输层 `requestId` 必须分离：前者跨网络重试复用以避免重复发短信，后者每次请求重新生成并用于 nonce/requestId 防重放。

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
- 未登录客户端通过 K107 读取 `zh-CN` 当前目录；每份正文不超过 256 KiB 且 SHA-256 必须与 `contentDigest` 一致，否则目录整体不可用。

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
