# 登录与会话流程

## 首次登录

```text
1. Flutter 生成临时 ECDH key pair 和 clientNonce
2. POST /supper-handshake
3. 校验 HTTPS 与服务端公钥策略，得到 handshakeId/sessionKey
4. handshake 密文调用“发送验证码”接口
5. 服务端限流并创建一次性 loginChallenge
6. 用户输入验证码
7. handshake 密文调用“验证码登录”接口
8. 服务端执行可补偿编排：
   - 验证 challenge/code，将其转成 120 秒内可消费的短信证明；失败次数仍在 challenge 上累计
   - 计算 KingClub 独立密钥的手机号 HMAC 指纹并查询本地登录身份投影
   - 投影命中时使用本地 `U... userAccount`
   - 投影缺失时先登记/复用 `identityProvisioningAttempt`，再在本地事务之外调用物业超级接口 `S260824000401`
   - 首次创建时由物业权威库原子写入统一账号、手机号登录身份和真实 KYC 状态占位/摘要
   - 物业调用成功后，KingClub 在单个本地事务内消费短信证明、upsert 账号/成员/手机号指纹投影、记录协议同意、撤销旧会话、创建新 Session/API Key 并写登录审计
   - apiKey 只加密保存，refreshToken 只保存受控哈希；两项明文只在成功响应中返回一次
   - 本地事务失败时复用同一 provisioning 幂等键重试，不回滚物业权威账号，也不重复发号
9. 密文返回凭据和最小用户/成员摘要
10. Flutter 保存敏感凭据到 Keychain/Keystore
11. 拉取完整个人资料并建立 WebSocket
```

## 会话恢复

1. App 启动读取安全存储。
2. 本地只判断“可能有会话”，不能据此授予业务权限。
3. 调用受保护的 session/profile 接口确认服务端状态。
4. 会话过期时使用 refresh token 刷新；刷新失败则清除凭据并重新握手。

## 注销

1. 调用加密 revoke/logout。
2. 服务端撤销 session 与关联 API Key，记录原因。
3. 关闭 WebSocket。
4. 清除 Keychain/Keystore、内存密钥和用户缓存。

## 风控与多设备

- 密码修改、风险命中、管理员冻结可撤销指定或全部会话。
- 新 KingClub 设备登录成功时，在同一事务内撤销该账号同 `clientAppCode=kingclub` 的旧会话和旧 API Key。
- 服务端向旧连接发布 `auth.session.revoked` 后关闭旧 WebSocket；旧客户端清除凭据并回到登录页。
- 单设备唯一范围是 `userAccount + clientAppCode`，物业 App 与 KingClub App 不互相踢下线。
- WebSocket 收到会话撤销事件后立即停用本地会话，并通过 API 再确认。
- 物业身份接口不可用时，首次注册不得在 KingClub 本地临时生成 `U...`；返回可重试错误，避免双重发号。
- 已存在且版本有效的本地身份投影允许正常登录；权威冻结、归并和身份版本变化通过已批准的身份事件同步更新并撤销会话。

## 固定时效参数

| 参数 | V1 默认值 |
|---|---:|
| 验证码有效期 | 300 秒 |
| 重发冷却 | 60 秒 |
| 单挑战最大失败次数 | 5 次 |
| 手机号发送上限 | 5 次/小时 |
| IP 发送上限 | 20 次/小时 |
| 已验证短信证明有效期 | 120 秒，仅服务端过程使用 |
| API Key/访问会话有效期 | 2 小时 |
| Refresh Token 有效期 | 30 天，成功刷新后滑动续期 |
| 提前刷新窗口 | 剩余 10 分钟 |
