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
8. 服务端原子执行：
   - 消费 challenge
   - 查找/创建 userAccount
   - 绑定 userLoginIdentity
   - 查找/创建 KingClub appMembership
   - 生成 apiKey 与 refreshToken
   - 加密保存 apiKey，哈希保存 refreshToken
   - 创建 authSession
   - 写登录审计
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
