# WebSocket 协议与事件

## 连接参数

当前服务端要求：`apiKeyId`、`sessionId`、`timestamp`、`nonce`、`requestId`、`clientId`、`sign`。

生产日志和代理配置必须对查询串脱敏；后续可评估 Flutter 客户端改用受支持的握手 Header，浏览器兼容方案另行设计。

## 帧要求

- `eventType`
- `encrypted=true`
- `data={iv,ciphertext,tag}`
- `sign`
- `seq`
- `timestamp`
- 可选 `traceId`

## 基础事件

| 方向 | eventType | 用途 |
|---|---|---|
| S→C | connection.ready | 连接就绪 |
| 双向 | ping / pong | 活性检查 |
| C→S | websocket.subscribe | 订阅授权频道 |
| C→S | websocket.unsubscribe | 取消订阅 |
| S→C | notification.* | 实时通知 |
| C→S | notification.ack | 收到确认 |
| C→S | notification.unread.list | 当前底座未读补偿 |
| C→S | business.event.publish | 通用业务事件入口，不等同聊天发送成功 |

## 聊天扩展前置

后续聊天功能必须另外定义：

- conversationId、messageId、clientMessageId
- 服务端接收、持久化、投递、送达、已读状态
- 每会话游标与历史分页
- 重复发送和乱序处理
- 撤回、删除、引用、附件和群成员权限

