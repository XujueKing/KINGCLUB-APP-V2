# Mock 场景与 Fake Runtime

- Scope ID：`KC-F-008`
- 文档状态：`Approved for Development`
- 所属业务域：`foundation`
- M0 范围：`In Release Scope`
- 设计版本：`Mock Runtime v1`
- 批准日期：2026-08-26

## 目标与用户价值

为本期 48 页提供完全离线、可重复、可重置的 UI 演示运行时。产品与开发可以从同一个场景入口复现主流程、异常流程、返回路径和生命周期变化，而不依赖真实超级接口、WebSocket、支付、推送或生产数据。

## 已确认事实

- 本期 48 页都已有页面级 Mock 场景编号或明确状态要求。
- 项目在整 App `UI Flow Approved` 前禁止连接真实接口和生产 SDK。
- 登录、会话、聊天、订单、支付、资产、储物和扫码都需要可控的异步结果与状态变化。

## 已确认方案

- 采用一个 App 级 `ScenarioRuntime`，由场景清单、虚拟时钟、Fake 端口注册表、内存数据集和事件总线组成。
- 每次启动明确选择一个 `scenarioId + seed`；相同输入必须得到相同初始数据和事件顺序。
- 场景数据只驻留内存或专用测试容器；重置不得读取系统通讯录、真实相册、真实定位、真手机号或旧 App 数据。
- 页面只依赖业务 Repository/port，不读取 `ScenarioRuntime`；场景切换通过依赖注入替换 Fake 实现。
- 网络、会话、WebSocket、权限、扫码、支付、推送、生命周期和时间推进全部可脚本化。
- 默认构建配置 `realIntegrationEnabled=false`；UI Mock 构建检测到真实 baseUrl、真实 adapter 或生产 SDK 时失败关闭。

## 页面与入口

本功能不拥有消费者业务页面。仅在 `dev/mock` 构建提供受保护的“场景控制面板”，它不是 KC-P 页面、不得进入生产导航，也不得被外部深链打开。

控制面板最小能力：选择场景、查看虚拟时间、推进事件、模拟前后台、重置数据、复制脱敏场景报告。生产构建必须通过编译配置剔除入口。

## 依赖与边界

- 依赖 Riverpod override/自有端口、类型化路由、Fake SessionView 和 Design System v1。
- 不模拟密码学正确性、真实支付结果、真实推送到达率或真实平台权限行为；这些属于集成/真机阶段。
- Fake DTO 字段必须来自批准契约或标注为 `mockOnly`，不得反向变成服务端事实。
- 页面不得根据 `isMock` 改变业务语义；差异只存在于 adapter 和开发控制面板。

## 文档

- [运行时与注入契约](runtime_contract.md)
- [全局场景与事件目录](scenario_catalog.md)
- [数据安全、测试与退出策略](safety_and_test.md)
- [验收标准](acceptance.md)

## 已确认决策

1. UI 阶段默认离线，所有外部能力由 Fake 驱动。
2. 场景采用稳定 ID、固定 seed、虚拟时间和显式事件，不依赖随机网络结果。
3. 开发控制面板不属于消费者页面，生产构建不可达。
4. Fake 与真实 adapter 实现同一自有端口，真实接入只替换 adapter。
5. 用户于 2026-08-26批准 `Mock Runtime v1`。

## 开发门禁

本模块达到文档准入。创建 Flutter 工程后只允许实现 Fake Runtime；项目达到 `UI Flow Approved` 前不得加入真实 adapter、真实凭据或生产 SDK。
