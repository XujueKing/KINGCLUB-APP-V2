# 超级接口调用流程

## 登录前

```text
客户端握手
  -> 获得 handshakeId/sessionKey
  -> 加密 interfaceId + params
  -> HMAC 签名
  -> 防重放校验
  -> 只允许 authPolicy=handshake 的接口
  -> 参数契约校验
  -> 执行并返回密文
```

## 登录后

```text
apiKeyId + sessionId 定位活动凭据
  -> 校验时间戳/签名/nonce/requestId
  -> 从会话得到可信 userAccount/businessLine
  -> 读取接口元数据
  -> 参数契约校验
  -> 权限与对象所有权校验
  -> 服务端注入 trusted context
  -> Routine/adapter 执行
  -> 审计
  -> 密文响应
```

## 失败规则

- 未知、停用或业务线不匹配的接口拒绝执行。
- 不支持的 authPolicy 按配置错误处理，不降级为公开。
- 客户端提交保留字段时拒绝请求。
- 参数错误不进入 Routine。
- 超时不泄露 SQL、Routine 名或敏感参数。
- 幂等接口用 requestId 返回首次结果；非幂等重放直接拒绝。

