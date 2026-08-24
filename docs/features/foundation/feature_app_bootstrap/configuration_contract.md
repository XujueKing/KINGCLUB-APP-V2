# 运行环境配置契约

- 文档状态：`In Review`
- 配置来源：受版本控制的 flavor 配置与 CI 注入的非秘密构建值

## 1. 环境模型

V1 固定三个环境，构建完成后不可在 App 内切换：

| 环境 | 用途 | 安装隔离 | 网络规则 |
|---|---|---|---|
| `dev` | 本地开发、Mock 与隔离服务 | 独立显示名、应用 ID 后缀和存储命名空间 | debug 构建可显式允许受控局域网地址 |
| `staging` | 联调、测试和预发布验收 | 独立应用 ID 后缀、签名和数据容器 | 仅已批准 HTTPS/WSS 测试域名 |
| `prod` | 正式发布 | 正式应用 ID、签名和生产数据容器 | 仅已批准 HTTPS/WSS 生产域名 |

正式 applicationId/bundleId、域名和签名资料由发布工作包确认；在确认前只保留 schema 字段，不把占位域名打入发布包。

## 2. AppEnvironment 字段

| 字段 | 类型/约束 | 敏感性 | 说明 |
|---|---|---|---|
| `schemaVersion` | 正整数，V1=`1` | 公开 | 不支持的版本失败关闭 |
| `environment` | `dev/staging/prod` | 公开 | 必须与构建 flavor 一致 |
| `clientAppCode` | 固定 `kingclub` | 公开 | 不允许运行时覆盖 |
| `clientType` | `android/ios`，由平台适配器产生 | 公开 | 不接受远端或页面输入 |
| `apiBaseUri` | 绝对 URI、无 query/fragment | 公开 | 路径由网络层追加 `/supper-*` |
| `webSocketBaseUri` | 绝对 WSS URI | 公开 | realtime 模块使用，bootstrap 不连接 |
| `allowedHosts` | 非空白名单 | 公开 | API/WSS host 必须命中 |
| `allowLocalCleartext` | 仅 `dev + debug` 可为 true | 公开 | staging/prod 必须为 false |
| `logLevel` | 受控枚举 | 公开 | prod 禁止 verbose/body logging |
| `optionalCapabilities` | 布尔 allowlist | 公开 | 推送、分析等只决定是否尝试初始化 |
| `buildInfo` | 版本、构建号、可选 commit 摘要 | 公开 | 用于诊断与发布追踪 |

配置中禁止出现数据库凭据、Basic Authorization、HMAC/API Key、签名私钥、短信密钥、Refresh Token、通用测试账号或可绕过证书校验的开关。

## 3. 校验顺序

```text
解析 schema
  -> environment 与 flavor/build mode 一致
  -> clientAppCode == kingclub
  -> 平台推导 clientType
  -> URI 语法和 scheme
  -> host allowlist
  -> cleartext/debug 双重门禁
  -> prod 日志/能力安全规则
  -> 生成不可变 AppEnvironment
```

任何一步失败返回稳定 `BootstrapFailure`，不得猜测默认生产地址，不得从 staging 回落 prod，也不得通过远程参数覆盖根地址。

## 4. 构建与注入

- 推荐通过独立 flavor 入口配合 `--dart-define-from-file` 注入非秘密值；实际命令在工程创建清单中冻结。
- 配置文件可以提交字段名和安全的开发默认值，真实生产域名可由受保护 CI 环境注入，但不能被当作秘密保护替代证书和鉴权。
- CI 必须对每个 flavor 执行 schema 校验，并反向扫描 prod artifact，确认不存在 dev/staging host。
- 测试只能通过根 Provider override 注入 `FakeAppEnvironment`；业务页面不得调用 `String.fromEnvironment`。

## 5. 数据与安装隔离

- 三个环境使用不同应用 ID/bundle ID 和 SecureStore service/account namespace。
- 缓存、数据库、日志队列、推送 token 和 WebSocket 状态不得跨环境复用。
- 升级安装时只允许读取同环境、同 schema 兼容范围的数据。
- 用户卸载/重装后的 Keychain 残留策略由 session/persistence 真机测试决定，bootstrap 只接收标准候选结果。

## 6. 发布门禁与回滚

- prod 构建若域名、业务线、日志级别、cleartext 或应用标识不匹配，CI 和运行时都必须失败。
- 服务地址变化通过新版本构建发布，不在 V1 使用无签名远程开关热切生产根地址。
- 回滚只能回到仍受服务端支持、配置 schema 兼容且签名一致的已验证版本。
