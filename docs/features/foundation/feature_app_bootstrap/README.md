# 应用启动与环境

- 文档状态：`In Review`
- 优先级：P0
- ADR：[Flutter Foundation 技术基线](../../../v2/adr/0001_flutter_foundation_baseline.md)

## 目标

用唯一、可测试的启动编排完成环境读取、错误捕获、依赖装配、安全会话快照和首屏交接。启动失败必须有确定状态，不能用空白页、无限 Splash 或本地用户缓存伪装为已登录。

## 当前建议的启动阶段

```text
P0 Widgets binding / platform readiness
  -> P1 读取并校验不可变环境配置
  -> P2 安装全局错误与脱敏日志出口
  -> P3 初始化 SecureStore 并读取 SessionBundle 快照
  -> P4 创建 ProviderScope、Router 与 App shell
  -> P5 启动鉴权页调用 K103/K104 复核
  -> P6 延迟初始化非关键 SDK
```

- P0～P4 是本地启动门槛；任何失败进入可诊断的 fatal/repair 状态。
- K103/K104 属于启动鉴权 feature，不在 `main()` 阻塞首帧，也不能由 bootstrap 直接授予业务权限。
- 推送、地图、媒体、产品埋点等非关键 SDK 在首帧后按需初始化；失败不得阻止用户打开登录页。
- 同一阶段只能有一个启动任务；热重载、生命周期恢复或重复通知不得重新构建全局容器。

## 环境契约

- `dev/staging/prod` 使用独立 applicationId/bundleId 后缀、显示名、API 地址、日志级别和数据容器。
- 公开环境值可通过受版本控制的 flavor 配置或 `dart-define` 注入；API Key、HMAC、签名私钥等服务端秘密不得进入 App。
- 环境在进程启动后不可切换；测试通过 Provider override 注入假配置。
- 配置缺失、URL 非 HTTPS（本地明确例外除外）或业务线不是 `kingclub` 时失败关闭。

## 边界

- bootstrap 只负责装配，不实现登录、路由决策、HTTP 重试、Token 刷新或厂商埋点业务。
- 页面和 feature 不允许读取全局环境变量或创建第二个依赖容器。
- 启动日志只能记录阶段、耗时、稳定错误分类和随机 installation/run ID，不记录会话或用户资料。

## 配套文档

- [验收标准](acceptance.md)
- [Foundation 索引](../README.md)
