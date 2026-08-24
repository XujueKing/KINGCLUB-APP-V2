# 网络与超级接口传输

- 文档状态：`In Review`
- 优先级：P0
- 当前建议：Dio 只作为底层 HTTP adapter，对 feature 暴露自有语义端口

## 目标

实现 KingClub 超级接口的 HTTPS、ECDH 握手、AES-GCM/HMAC 密文封装、防重放、错误映射、超时、取消和可观察请求生命周期，同时禁止通用重试破坏业务幂等或一次性凭据。

## 分层

```text
Feature Repository
  -> Semantic SuperInterfaceClient
      -> SecureEnvelopeCodec
      -> HandshakeCoordinator
      -> RequestPolicy / ErrorMapper
      -> HttpTransport port
          -> Dio adapter
```

- interfaceId 只允许存在于 data adapter/接口注册层，页面和 domain 使用 `requestSms/login/currentAgreements` 等语义方法。
- Dio interceptor 只处理传输元数据、受控日志和明确的鉴权装配，不包含页面导航或业务状态。
- 握手、nonce、requestId、timestamp 和密文 generation 由 SecureEnvelope 层统一生成；禁止重放相同密文包。

## 重试分类

| 场景 | V1 规则 |
|---|---|
| 请求确定未发出 | 可由调用方策略重试，新握手/nonce/requestId |
| K101 结果未知 | 复用业务 idempotencyKey，重新生成传输标识 |
| K102 发出后结果未知 | 禁止自动重试，交给登录页失败关闭 |
| K103 刷新 | 只由 SessionCoordinator SingleFlight，页面不得重试 |
| 只读 K104/K107 | 仅在策略允许、预算内退避重试 |
| 其他写操作 | 必须先有该接口自己的幂等契约 |

## 安全与错误

- 只允许 HTTPS/WSS；开发例外必须受 flavor 和构建模式双重约束，生产不可配置绕过证书验证。
- 不记录明文/密文请求体、手机号、验证码、API Key、Refresh Token、challenge 或完整响应。
- 对外统一领域错误：稳定 code、可重试分类、requestId、可选 retryAt；不得让 Widget 解析 DioException。
- 客户端时钟偏差只用于生成请求，服务端仍是权威；明确时间窗错误进入可恢复提示，不通过扩大窗口绕过。
- 证书 pinning 暂不默认启用；如上线前决定启用，必须有双证书轮换与远程失效预案。

## 配套文档

- [验收标准](acceptance.md)
- [第一批超级接口契约](../feature_super_interface/interface_contracts_v1.md)
- [Foundation 索引](../README.md)
