# 超级接口契约与元数据

## 必须补齐的元数据能力

| 能力 | 当前状态 | 目标 |
|---|---|---|
| interfaceId | 已存在 | KingClub 命名空间/兼容映射 |
| businessLine | 文档有、查询和表结构未落实 | 元数据和查询强制隔离，或使用独立库实例 |
| interfaceKey | 已读取、未执行校验 | 请求进入 executor 前强制校验 |
| interfaceReturn | 已读取、未执行校验 | 测试/非生产至少校验返回契约 |
| authPolicy | 粗粒度 | 增加 role/scope/ownership 策略 |
| idempotency | 未见接口级配置 | 写接口明确策略和 TTL |
| sensitivity/audit | 平台审计存在 | 接口级敏感等级和脱敏策略 |

## 可信上下文

建议 `DbRoutineExecutor` 构造服务端 envelope，而不是直接传 `request.params`：

```json
{
  "params": { "businessInput": "..." },
  "auth": {
    "userAccount": "from active session",
    "sessionId": "from active session",
    "apiKeyId": "from active session",
    "businessLine": "from deployment/session"
  },
  "request": {
    "requestId": "verified request id",
    "traceId": "server trace id"
  }
}
```

客户端输入中出现 `auth`、`request` 或其他保留根字段时直接拒绝。

## Flutter SDK 边界

Flutter 端提供：

- handshake 管理
- 请求/响应加解密和签名
- nonce/requestId 生成
- 会话安全存储
- 统一错误映射
- 接口名到 interfaceId 的集中注册

页面和业务 ViewModel 不接触加密、Header 或裸 `interfaceId`。

