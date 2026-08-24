# 应用启动失败与恢复矩阵

- 文档状态：`Approved for Development`
- 原则：关键安全依赖失败关闭，非关键能力独立降级

## 1. 稳定失败类型

| 稳定类型 | 示例来源 | 用户结果 | 自动重试 | 本地处理 |
|---|---|---|---|---|
| `configurationInvalid` | schema、flavor、host、scheme 不匹配 | fatal，提示更新或重装 | 否 | 不启动网络与会话读取 |
| `diagnosticsDegraded` | 完整诊断出口或供应商 adapter 不可用 | App 保持可用 | 首帧后按预算 | 保留最小脱敏 fallback，禁用供应商上报 |
| `secureStoreUnavailable` | 插件不可用、Keychain/Keystore 无法访问 | repair，可手动重试 | 否 | 不回落普通存储 |
| `sessionCandidateCorrupt` | bundle 缺字段、摘要/版本错误 | 继续匿名候选 | 否 | 由 session 层整包清理并记安全分类 |
| `sessionCandidateAbsent` | 首次安装或已注销 | 正常进入鉴权页 | 否 | 不记录 error |
| `compositionFailed` | provider 图循环、必要 adapter 缺失 | fatal | 否 | 不创建部分可用根容器 |
| `routerCreationFailed` | 初始路由或生成配置错误 | fatal | 否 | 不尝试字符串路由兜底 |
| `optionalInitializationFailed` | 推送、地图、分析初始化失败 | App 保持可用 | 各 adapter 自定一次预算 | 标记 capability unavailable |
| `staleGenerationResult` | 重试后旧 Future 返回 | 无 UI 变化 | 否 | 丢弃并记录 debug 计数 |

## 2. Fatal/repair UI

- fatal shell 由已经渲染的 `BootstrapHost` 提供，是本地、无网络、无会话依赖的最小 Widget。
- 只显示通用标题、简短操作建议、重试（仅可恢复类型）和退出/系统返回能力。
- `configurationInvalid`、`compositionFailed`、`routerCreationFailed` 默认不循环重试；相同构建重试不会改变确定性结果。
- `secureStoreUnavailable` 允许用户手动重试；连续失败仍停留 repair，不删除数据、不降级为 SharedPreferences。
- UI 与无障碍公告不得显示内部错误码、URL、路径、堆栈或配置正文。

## 3. 会话候选边界

以下结果不是 bootstrap 认证结论：

| 候选结果 | 交给 `/auth/bootstrap` 的含义 |
|---|---|
| `absent` | 无可恢复凭据，启动鉴权页导航匿名登录 |
| `present` | 存在完整候选，启动鉴权页必须 K103/K104 复核 |
| `corruptCleared` | 残留已由 session 层清理，按匿名处理并保留安全事件分类 |
| `unavailable` | 安全存储不可访问，bootstrap 停在 repair，不进入登录页 |

bootstrap 不知道 bundle 内容，也不能把网络离线当作本地初始化失败。网络错误只会在首帧后的启动鉴权页出现。

若损坏 bundle 无法完整清除，不得按匿名继续；统一升级为 `secureStoreUnavailable` 并停在 repair，避免旧凭据残留与新登录状态混合。

## 4. 非关键能力降级

- 每项 optional initializer 返回 `available/unavailable/deferred`，不抛出到根 Zone 形成崩溃循环。
- 推送不可用不阻止登录，但消息入口应展示明确能力状态；具体体验由推送功能文档定义。
- 产品分析未初始化时直接丢弃非必要事件，不在普通磁盘无限排队。
- optional initializer 可在下一次前台恢复或用户进入相关功能时按自身策略重试，但不得重新运行 bootstrap。

## 5. 诊断与隐私

允许字段：`stage`、`failureCategory`、`environment`、`appVersion/buildNumber`、`platform`、`runId`、耗时桶和受控 adapter 名称。

禁止字段：异常对象整体序列化、配置全文、主机以外的完整 URL、SessionBundle、Token、手机号、`userAccount`、`deviceInstanceId`、原始设备标识以及 SecureStore key/value。
