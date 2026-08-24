# 日志与可观测性验收

- [ ] operational/crash/product 三类信号端口分离
- [ ] 每类事件都有版本化 allowlist schema 和字段上限
- [ ] 自动测试扫描手机号、验证码、Token、证件和正文泄漏
- [ ] 启动、导航、网络、登录和会话关键路径可用 requestId/traceId 关联
- [ ] 离线队列有容量、TTL、环境隔离和清理策略
- [ ] 厂商 SDK 失败不阻塞启动或业务主流程
- [ ] 产品分析在隐私与运营方案批准前保持关闭
- [ ] 用户批准 ADR-0001 与本模块，状态更新为 `Approved for Development`
