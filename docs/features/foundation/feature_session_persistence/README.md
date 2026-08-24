# 会话与安全持久化

- 文档状态：`In Review`
- 优先级：P0
- 当前建议：自有 SecureStore/SessionRepository 端口，平台 adapter 使用 `flutter_secure_storage`

## 目标

让 API Key、Refresh Token 和会话元数据以完整 bundle 安全提交、恢复、轮换和删除；全 App 只有一个 SessionCoordinator 决定认证状态与刷新任务。

## SessionBundle

```text
schemaVersion
generation
sessionId
apiKeyId
apiKey
refreshToken
refreshTokenVersion
expiresAt
refreshExpiresAt
clientAppCode / clientType / deviceId
minimal account + membership snapshot
```

- 不保存手机号、验证码、challenge、握手私钥、协议正文或网络请求体。
- 页面只能读取脱敏 SessionView，不得取得 apiKey/refreshToken。
- 任何 bundle 字段缺失、版本未知、平台解密失败或环境不匹配都视为不可恢复，清除后回匿名态。

## 原子提交协议

1. 把完整 bundle 写入新的 generation 暂存键。
2. 回读并验证 schema、环境、完整字段与摘要。
3. 原子语义切换活动 generation 指针。
4. 删除旧 generation；失败则删除暂存且不改变当前活动指针。

底层 Keychain/Keystore 插件不保证多键事务，因此业务层必须实现上述 bundle/pointer 协议。K102/K103 的一次性响应不能由 Widget 逐字段写入。

## SessionCoordinator

- 状态：`unknown/anonymous/validating/authenticated/refreshing/revoked/expired/restricted`。
- 启动只读取候选 bundle，必须通过 K104 或 K103→K104 复核后进入 authenticated。
- 所有并发刷新共享一个 SingleFlight；成功后原子替换整套 bundle，失败按稳定错误决定保留、清除或撤销。
- 注销/撤销时先阻止新请求和 WebSocket 重连，再清除本地 bundle；远端结果不确定时不得声称已远端注销。
- Android 自动备份必须排除会话密钥材料；iOS Keychain 可访问性和卸载后残留策略在实现前做真机测试。

## 配套文档

- [验收标准](acceptance.md)
- [登录状态机](../../identity/feature_login_session/auth_state_machine.md)
- [Foundation 索引](../README.md)
