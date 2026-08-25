# WebSocket 实时传输基础

- Scope ID：`KC-F-022`

- 文档状态：`Approved for Development`
- 所属业务域：messaging / realtime foundation
- 最后更新：2026-08-25

## 目标

基于新服务端 `/ws` 建立与登录会话绑定、全程加密、可重连和可补偿的 Flutter 实时通道，为通知和后续聊天功能提供基础。

## 已确认事实

- 新服务端 WebSocket 使用 API Key 会话签名并派生双向密钥。
- 帧使用 AES-256-GCM、HMAC、timestamp 和递增 seq。
- 频道授权来自 `authSession.allowedChannels`，并隐式允许用户、会话和当前业务线频道。
- 已实现 ping/pong、订阅、取消订阅、通知确认、未读通知查询和业务事件发布。
- 当前没有完整的 KingClub 会话/消息持久化与离线补偿协议。
- 同一 session 可以同时注册多个 socket，未定义重复连接处理。

## 当前建议范围

- Flutter 连接签名与密文帧 SDK
- 单连接状态机和指数退避重连
- 前后台切换与网络变化处理
- ping/pong 和超时检测
- session 撤销处理
- 通知 ACK 与断线后的 API 补偿
- 为会话、通知和单聊定义事件 envelope，但 WebSocket 不直接拥有业务状态

## 当前建议决策

- 每个 auth generation 在单个 App 进程内只能有一个活动 socket 和一个 `ConnectionCoordinator`；旧连接必须关闭后才能发布新连接。
- 心跳参数优先由 `connection.ready` 协商，客户端只设置安全上下界；连续错过两个权威心跳窗口后判定断线。
- App 进入后台后停止业务订阅并允许系统关闭 socket；恢复前台后重连，再用 HTTP cursor 补偿，不能依赖后台常驻。
- 频道只能使用 API/ready 返回的 `ChannelRef`，客户端不得拼接 userAccount 或 conversationId 订阅频道。
- `eventId` 负责事件去重，`clientMessageId` 负责发送幂等，`messageId/serverSequence` 负责持久消息身份和会话顺序。
- 推送只唤醒/提示；锁屏不展示消息正文，点击后仍通过 API 重新鉴权和补拉。

## 相关文档

- [连接与恢复流程](flow.md)
- [协议与事件](data_and_api.md)
- [Mock/Fake 场景](mock_scenarios.md)
- [验收标准](acceptance.md)

## 开发准入

- [x] 用户确认单进程单连接、后台恢复、协商心跳和推送隐私策略
- [x] 聊天补偿游标和消息幂等职责已形成评审契约
- [x] 频道改用服务端签发/返回的 ChannelRef，不由客户端拼接
- [x] 状态更新为 Approved for Development
