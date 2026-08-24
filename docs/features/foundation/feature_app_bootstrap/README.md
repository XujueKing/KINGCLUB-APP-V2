# 应用启动与环境

- 文档状态：`In Review`
- 优先级：P0
- ADR：[Flutter Foundation 技术基线](../../../v2/adr/0001_flutter_foundation_baseline.md)

## 目标

用唯一、可测试的启动编排完成环境读取、错误捕获、依赖装配、安全会话快照和首屏交接。启动失败必须有确定状态，不能用空白页、无限 Splash 或本地用户缓存伪装为已登录。

## 当前建议的启动阶段

```text
P0 Widgets binding + 最小错误 fallback + runApp(BootstrapHost)
  -> P1 在 BootstrapHost 内读取并校验不可变环境配置
  -> P2 安装完整全局错误与脱敏日志出口
  -> P3 初始化 SecureStore 并通过 SessionRepository 读取候选会话结果
  -> P4 创建唯一 ProviderScope、Router 与正式 App Root
  -> P5 正式 App Root 交接 /auth/bootstrap，由启动鉴权页调用 K103/K104 复核
  -> P6 延迟初始化非关键 SDK
```

- P0 先渲染只依赖本地常量的 `BootstrapHost`；P1～P4 是正式 App Root 的本地门槛，配置或关键安全依赖失败时由该 Host 显示 fatal/repair，不出现白屏。完整诊断或供应商 adapter 失败则保留最小脱敏 fallback 并降级继续。
- bootstrap 只接收 `SessionCandidateResult`，不得读取、解析或复制 Token 等凭据字段。
- K103/K104 属于启动鉴权 feature，不在 `main()` 阻塞首帧，也不能由 bootstrap 直接授予业务权限。
- 推送、地图、媒体、产品埋点等非关键 SDK 在首帧后按需初始化；失败不得阻止用户打开登录页。
- 同一阶段只能有一个启动任务；热重载、生命周期恢复或重复通知不得重新构建全局容器。

## 环境契约

- `dev/staging/prod` 使用独立 applicationId/bundleId 后缀、显示名、API 地址、日志级别和数据容器。
- 公开环境值可通过受版本控制的 flavor 配置或 `dart-define` 注入；API Key、HMAC、签名私钥等服务端秘密不得进入 App。
- 环境在进程启动后不可切换；测试通过 Provider override 注入假配置。
- 配置缺失、URL 非 HTTPS（本地明确例外除外）或业务线不是 `kingclub` 时失败关闭。

具体字段、构建约束与校验规则见[运行环境配置契约](configuration_contract.md)。

## 边界

- bootstrap 只负责装配，不实现登录、路由决策、HTTP 重试、Token 刷新或厂商埋点业务。
- 页面和 feature 不允许读取全局环境变量或创建第二个依赖容器。
- 启动日志只能记录阶段、耗时、稳定错误分类和本次进程随机 `runId`，不记录 `deviceInstanceId`、会话或用户资料。

## 交付状态

- **已确认事实**：ADR-0001、Flutter 3.47.1、Riverpod 3 + codegen 和单 App package 基线已批准。
- **当前建议**：采用本目录定义的 P0～P6 编排、三环境不可变配置、单次启动 generation 和关键/非关键初始化边界。
- **待用户决策**：确认本模块设计后，将文档状态更新为 `Approved for Development`；这不代表其他四个 foundation 模块获批。

## 配套文档

- [启动编排与状态](startup_flow.md)
- [运行环境配置契约](configuration_contract.md)
- [失败与恢复矩阵](failure_matrix.md)
- [测试计划](test_plan.md)
- [验收标准](acceptance.md)
- [Foundation 索引](../README.md)
