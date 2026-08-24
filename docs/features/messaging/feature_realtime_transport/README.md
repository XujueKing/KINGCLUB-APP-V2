# WebSocket 实时传输基础

- Scope ID：`KC-F-022`

- 文档状态：`In Review`
- 所属业务域：messaging / realtime foundation
- 最后更新：2026-08-24

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
- 为后续聊天定义事件 envelope，但本阶段不实现聊天页面

## 相关文档

- [连接与恢复流程](flow.md)
- [协议与事件](data_and_api.md)
- [验收标准](acceptance.md)

## 开发准入

- [ ] 多设备/重复连接策略已确认
- [ ] 心跳与超时参数已确认
- [ ] 聊天补偿游标和消息幂等键已确认
- [ ] 频道命名与授权模型已确认
- [ ] 状态更新为 Approved for Development
