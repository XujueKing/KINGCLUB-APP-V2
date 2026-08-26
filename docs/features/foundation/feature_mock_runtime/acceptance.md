# Mock Runtime 验收

## 文档准入

- [x] ScenarioRuntime、manifest、虚拟时钟、数据集、事件和 Fake 端口边界明确
- [x] 稳定 scenarioId/seed、generation、重置和迟到结果规则明确
- [x] J01～J07 串联本期 48 页主要流程
- [x] 网络、会话、实时、支付、权限、扫码和生命周期事件可脚本化
- [x] 纯虚构数据、deny-all 网络、生产构建剔除和隐私规则明确
- [x] 测试、复现、真实 adapter 替换和回滚策略明确
- [x] 用户于 2026-08-26批准 `Mock Runtime v1`

## UI 实现验收

- [ ] 相同 manifest/version/seed 产生相同初始状态和事件顺序
- [ ] soft/hard reset、虚拟时间、场景切换和旧 generation 丢弃正确
- [ ] 48 页适用状态及 J01～J07 可离线演示
- [ ] 页面和 domain 不读取 fixture 或 mock 开关
- [ ] Mock 构建无真实出站请求、生产域名、凭据或第三方生产 SDK
- [ ] 自动化测试可输出脱敏、可复现的场景报告

当前批准允许实现 Fake Runtime，不代表 UI 已实现或整 App 已达到 `UI Flow Approved`。
