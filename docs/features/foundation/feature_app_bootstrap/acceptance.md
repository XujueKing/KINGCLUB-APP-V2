# 应用启动与环境验收

- [ ] dev/staging/prod 配置完全隔离，生产包不能指向测试服务
- [ ] 配置无效、SecureStore 不可用和依赖装配失败有确定错误页
- [ ] 首帧前不等待 K103/K104 或非关键第三方 SDK
- [ ] 本地 SessionBundle 只决定恢复候选，不直接开放受保护路由
- [ ] 启动 SingleFlight 防止重复初始化和多容器
- [ ] 测试可覆盖每个阶段成功、失败、超时和恢复
- [ ] 启动日志不含 Token、手机号、账号或设备硬件标识
- [ ] 用户批准 ADR-0001 与本模块，状态更新为 `Approved for Development`
