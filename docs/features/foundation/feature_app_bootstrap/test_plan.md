# 应用启动与环境测试计划

- 文档状态：`Approved for Development`
- 目标：在不访问真实生产服务、不读取真实用户凭据的前提下证明启动确定性和安全边界

## 1. 测试替身

实现前必须能替换以下端口：

- `EnvironmentLoader`
- `DiagnosticsInstaller`
- `SecureStore`
- `SessionRepository.inspectCandidate`
- `RootContainerFactory`
- `RouterFactory`
- `OptionalInitializer`
- `Clock/RunIdFactory/BuildInfoProvider`

测试禁止 mock Dio、Keychain 或 Riverpod 内部实现细节；应围绕上述自有端口验证行为。

## 2. 单元测试矩阵

| 编号 | 场景 | 预期证据 |
|---|---|---|
| AB-U01 | 合法 dev/staging/prod 配置 | 生成不可变环境，字段与 flavor 一致 |
| AB-U02 | prod 使用 HTTP、测试 host 或 verbose 日志 | `configurationInvalid`，未打开 SecureStore |
| AB-U03 | `clientAppCode != kingclub` 或未知 schema | 失败关闭，无默认值回落 |
| AB-U04 | 两个调用并发执行 `runOnce` | 共享同一 Future/结果，各 adapter 只创建一次 |
| AB-U05 | SecureStore 不可用 | `secureStoreUnavailable`，不创建普通存储替代 |
| AB-U06 | 会话 absent/present/corrupt | 只输出对应候选枚举，不泄露 bundle 字段 |
| AB-U07 | provider 或 router 创建失败 | 进入稳定 fatal，部分容器不可见 |
| AB-U08 | 新 generation 后旧任务完成 | 旧结果被丢弃，不覆盖当前状态 |
| AB-U09 | optional initializer 失败 | 已 ready 的 App 不回退、不崩溃 |
| AB-U10 | 日志事件序列化 | allowlist 外字段被拒绝或脱敏 |
| AB-U11 | 首次生成/再次读取 deviceInstanceId | 同安装同环境稳定、跨环境不同，且不是硬件标识派生 |

## 3. Widget 测试

- 正常路径先渲染唯一 `BootstrapHost`，随后切换到以 `/auth/bootstrap` 为初始位置的正式 App Root。
- SecureStore 人为挂起时 BootstrapHost 首帧仍能渲染，且不存在第二个 Router 或 ProviderScope。
- critical failure 渲染本地 fatal/repair shell，不出现空白屏和无限 Splash。
- repair 连点重试只产生一个新 generation，按钮在任务期间禁用。
- 字体放大、读屏和横竖屏变化不重启 coordinator，错误操作区不溢出。
- fatal 文案不包含异常原文、URL、路径、错误堆栈或 requestId。

## 4. 集成测试

| 编号 | 环境 | 流程 |
|---|---|---|
| AB-I01 | dev + fake session absent | 冷启动 → BootstrapHost 首帧 → App Root → `/auth/bootstrap` → 手机号登录页 |
| AB-I02 | dev + fake session present | 冷启动 → BootstrapHost 首帧 → App Root → 启动鉴权 feature 使用 Mock K104 → 安全目标页 |
| AB-I03 | dev + corrupt bundle | session 层整包清理 → 匿名流程，无凭据日志 |
| AB-I04 | dev + SecureStore failure | repair → 恢复 adapter → 单次重试成功 |
| AB-I05 | dev + optional SDK failure | 登录主流程可用，能力状态为 unavailable |
| AB-I06 | staging artifact scan | 不含 dev host、cleartext 开关和 prod 数据容器 |
| AB-I07 | prod artifact scan | 不含 dev/staging host、测试账号、密钥和 verbose logging |

Mock K103/K104 只是启动鉴权 feature 的批准契约，不由 bootstrap 测试直接调用网络。

## 5. 真机与发布验证

- Android API 24 与当前目标 API：首次安装、升级安装、冷/热启动、锁屏恢复、低内存重建。
- iOS 15 与当前目标版本：首次安装、升级安装、冷/热启动、后台恢复、Keychain 可访问性。
- dev/staging/prod 可并存安装且数据不串用；生产构建无法通过页面、深链或远程配置切换环境。
- 在目标低端机取得首帧、鉴权完成、首个可交互页基线后，再另行批准性能阈值。

## 6. 通过标准

- AB-U01～U11、AB-I01～I07 全部自动化通过。
- Android/iOS 真机矩阵不存在空白页、无限 Splash、重复容器或凭据泄漏。
- `git` 中不存在真实生产密钥；artifact 主机与构建 flavor 反向扫描通过。
- 实现差异先回写本文档，再更新模块为 `Implemented`。
