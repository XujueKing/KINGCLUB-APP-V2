# WebSocket 连接与恢复流程

## 建立连接

1. HTTP 登录会话已确认有效。
2. Flutter 生成 clientId、timestamp、nonce、requestId。
3. 使用 API Key 派生签名并连接 `/ws`。
4. 校验首个加密 `connection.ready` 帧。
5. 订阅服务端返回且仍获授权的 ChannelRef。
6. 根据 `connection.ready` 协商参数启动单一心跳计时器。

同一 auth generation 只允许一个 ConnectionCoordinator、一个活动 socket 和一个心跳计时器。新 generation 建立前先销毁旧连接、订阅和密钥。

## 断线重连

```text
断线
  -> 停止旧心跳并释放旧 socket
  -> 判断网络和 App 生命周期
  -> 指数退避 + jitter
  -> 每次重连生成新的 timestamp/nonce/requestId 和连接密钥
  -> 成功后清零重试状态
  -> 重新订阅
  -> 通过 HTTP 游标补拉遗漏消息
```

## 会话失效

- WebSocket 认证失败或收到撤销事件时暂停重连。
- 先尝试受控刷新会话；失败则彻底清除凭据并进入登录。
- 不使用无限重连掩盖已撤销账号。

## App 生命周期

- 前台且网络可用时允许连接和订阅。
- 进入后台后停止业务订阅/心跳，允许平台关闭连接；不承诺后台常驻。
- 回前台先校验会话，再用新连接参数重连，最后按 HTTP cursor 补拉通知、会话摘要和消息。
- 推送只提示有变化，不能携带权威业务对象或替代补拉。

## 消息处理

- seq 只保证单次连接内顺序。
- 业务消息必须有持久化 messageId/eventId 做跨连接幂等。
- ACK 表示客户端收到，不等于业务处理成功。
- WebSocket 不作为唯一数据源，断线后通过 API 补偿。
- `eventId` 去重实时事件；`clientMessageId` 去重发送命令；两者不可混用。
