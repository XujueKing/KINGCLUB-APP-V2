# 应用启动编排与状态

- 文档状态：`Approved for Development`
- 适用范围：Flutter 进程创建至首帧交接 `/auth/bootstrap`

## 1. 责任边界

`AppBootstrapCoordinator` 只在最小 `BootstrapHost` 内编排本地关键依赖并产出一次不可变的 `BootstrapSnapshot`。它不调用 K 接口、不判断用户已经登录、不解析深链目标、不连接 WebSocket，也不初始化具体业务 Repository。

```text
main
  -> ensure platform binding
  -> install minimal guarded error fallback
  -> runApp(BootstrapHost)
  -> BootstrapCoordinator.runOnce()
      -> load + validate AppEnvironment
      -> enrich guarded diagnostics
      -> open SecureStore adapter
      -> SessionRepository.inspectCandidate()
      -> compose root ProviderContainer
      -> create Router/App shell
  -> BootstrapHost 切换为正式 App Root
  -> /auth/bootstrap 接管 K103/K104 与最终路由
  -> OptionalInitializer 在首帧后运行
```

`BootstrapHost` 不是业务页面或第二套 App 容器。它只负责首帧品牌占位、fatal/repair 状态和承载唯一正式 App Root；切换后不得保留第二个 Router 或 ProviderScope。

关键分工：

| 能力 | bootstrap | 下游所有者 |
|---|---|---|
| 环境配置校验 | 编排并失败关闭 | configuration adapter 实现规则 |
| 全局错误捕获 | `runApp` 前安装最小 fallback，配置完成后增强 | observability 处理供应商 adapter |
| 安全存储 | 打开 adapter，获取候选结果 | session/persistence 解释、轮换和删除 bundle |
| 登录复核 | 不执行 | 启动鉴权 feature 调用 K103/K104 |
| 路由目标 | 只建立 `/auth/bootstrap` 初始入口 | navigation 守卫消费安全 RouteIntent |
| 第三方 SDK | 只触发非关键初始化队列 | 对应 adapter 自己负责结果和降级 |

## 2. 状态模型

同一进程只有一个 coordinator 和一个活动 generation。推荐使用不可变状态：

| 状态 | 含义 | 下一状态 |
|---|---|---|
| `idle` | 尚未启动 | `preparingPlatform` |
| `preparingPlatform` | Flutter binding、最小错误 fallback 和 BootstrapHost 首帧 | `validatingConfiguration`、`failed` |
| `validatingConfiguration` | 读取并校验编译期环境 | `installingDiagnostics`、`failed` |
| `installingDiagnostics` | 安装 Flutter/Platform/Zone 错误出口 | `openingLocalSecurity`、`failed` |
| `openingLocalSecurity` | 初始化 SecureStore 并检查候选会话 | `composingApplication`、`failed` |
| `composingApplication` | 创建根 ProviderScope、Router 与 shell | `ready`、`failed` |
| `ready` | 已生成唯一 BootstrapSnapshot，可把 Host 切换为正式 App Root | 终态 |
| `failed` | 关键阶段无法安全继续 | 新 generation 重试或终止 |

状态只允许单向前进。旧 generation、已完成 Future、后台回调或测试热重载不得把 `ready/failed` 改回中间状态。

## 3. BootstrapSnapshot

允许交给根容器的最小快照：

```text
environment             已校验 AppEnvironment
runId                   每次进程随机生成，不跨安装追踪
deviceInstanceId        当前环境随机安装标识；只通过受限 DeviceContext 暴露
buildInfo               appVersion/buildNumber/commit 可选摘要
sessionCandidate        absent | present | corruptCleared | unavailable
startupDiagnostics      阶段耗时桶与稳定警告，不含原始异常对象
```

`sessionCandidate=present` 只代表安全存储存在可供 session 层复核的完整 bundle；不得包含 Token，不得把根路由标记为 authenticated。

`deviceInstanceId` 在当前应用安装和环境内稳定，首次运行以安全随机数生成；卸载重装、用户明确重置本地身份或切换环境时重新生成。它作为超级接口 `deviceId` 的可信应用上下文来源，但禁止由 IMEI、Android ID、IDFA、手机号或账号派生，也禁止进入日志和第三方埋点。

## 4. 并发与生命周期

- `runOnce()` 为进程级 SingleFlight；并发调用共享同一结果，不创建第二个 ProviderContainer。
- 用户在 fatal 页面重试时必须创建新 generation，并让旧 generation 的所有结果失效。
- BootstrapHost 显示期间进入后台不重启编排；若平台暂不可用，回前台后只能按失败矩阵进行一次显式重试。
- 热重载保留现有根容器；热重启视为新进程启动语义。
- App shell 建立后，生命周期恢复只通知 session/navigation/realtime，不重新运行 P0～P4。

## 5. 首帧与非关键初始化

- 原生 Launch Screen 只遮罩 BootstrapHost 首帧，不承担鉴权或远程配置。
- BootstrapHost 首帧不等待 SecureStore、K103/K104、推送注册、地图、媒体预热、产品分析、广告或远程运营配置。
- P1～P4 完成后才挂载正式 App Root；这段时间 Host 可以显示本地品牌占位，但不得人为增加最短展示时长。
- P6 的每项任务独立超时、独立降级；一个任务失败不能取消其他任务或撤销已渲染 App。
- 首帧、启动鉴权完成、首个可交互业务页是三个独立性能节点，必须分别记录耗时桶。
- 正式性能阈值在获得 Android/iOS 目标机型基线后冻结；文档阶段不伪造毫秒承诺。

## 6. 安全不变量

- 生产环境任何配置校验失败都失败关闭，不回落 dev/staging。
- bootstrap 不持有 `apiKey`、`refreshToken`、手机号或 `userAccount`。
- `runId` 每次进程变化；`deviceInstanceId` 只在当前安装和环境内稳定，且不由 IMEI、Android ID、IDFA 等硬件标识直接派生。
- 日志只记录阶段名、耗时桶、结果分类和受控构建信息。
- fatal UI 不展示 URL、堆栈、异常原文、路径、requestId 或配置值。
