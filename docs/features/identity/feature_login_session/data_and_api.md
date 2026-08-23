# 登录数据与接口

## 复用模型

- `userAccount`：平台永久账号
- `userLoginIdentity`：手机号/微信等登录标识
- `userProfile`：最小公开资料
- `userApiKey`：非 Web 终端 API Key 密文
- `authSession`：登录会话和 refresh token 哈希

## 建议新增模型

- `appMembership`：KingClub 成员状态，不与账户冻结/KYC 混用
- `legacyIdentityMap`：旧 `k_user.userAccount` 映射
- `loginChallenge`：验证码哈希、场景、TTL、尝试次数、消费时间
- `consentRecord`：协议版本和同意证据
- `deviceRegistration`：设备、推送 token、最近登录和风险摘要

## 建议接口语义

具体 interfaceId 在分类和命名空间确认后分配：

| 语义 | 鉴权 | 幂等/限制 |
|---|---|---|
| auth.sms.send | handshake | 手机号/设备/IP 限流，同 challenge 幂等 |
| auth.sms.login | handshake | challenge 单次消费，失败次数上限 |
| auth.session.refresh | refresh credential + encryption | refresh token 轮换，旧 token 重用检测 |
| auth.session.logout | session | 幂等撤销 |
| auth.session.me | session | 返回最小身份与成员状态 |
| auth.session.revoke_all | session + 二次验证 | 高风险操作 |

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

