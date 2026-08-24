# ADR-0001：Flutter Foundation 技术基线

- 状态：`Accepted / Approved for Development`
- 日期：2026-08-24
- 批准日期：2026-08-24
- 影响范围：Flutter iOS/Android 工程、全部 feature、CI 与发布链

## 背景

首批登录页面的产品、接口、状态和验收文档已经批准，但 App 工程尚未创建。必须先冻结 SDK、平台下限、依赖装配、导航、网络、会话存储和日志边界，避免页面代码反向决定架构。

## 已确认事实

- Flutter `3.47` 已进入官方 stable 发布线；本机已升级并固定为 Flutter `3.47.1 / Dart 3.13.1 / DevTools 2.60.0`。
- Flutter 官方当前发布的移动平台支持矩阵仍以 Android API 24 与 iOS 15 为最低支持版本。
- Flutter 官方不建议多数 App 使用传统 named routes；复杂深链/多 Navigator 场景建议 Router 包，例如 `go_router`。
- K101～K107 使用 ECDH/AES/HMAC 超级接口协议；一次性登录响应、请求重放和未知结果不能交给通用 HTTP 自动重试。

官方依据：[Flutter SDK archive](https://docs.flutter.dev/install/archive)、[supported platforms](https://docs.flutter.dev/reference/supported-platforms)、[navigation and routing](https://docs.flutter.dev/ui/navigation)、[Flutter testing](https://docs.flutter.dev/testing/overview)。

## 已确认决策

| 决策 | V1 基线 | 原因 |
|---|---|---|
| Flutter SDK | 固定 `3.47.1 stable` | 使用 2026-08-24 实际可用的官方稳定补丁版本 |
| Dart SDK | 使用 Flutter 3.47.1 随附的 `3.13.1` | 避免 Flutter/Dart 组合漂移 |
| Android 最低版本 | API 24 | 当前 Flutter 官方支持下限 |
| iOS 最低版本 | iOS 15 | 当前 Flutter 官方支持下限 |
| 工程形态 | 单一 App package，feature-first | 首期无需 monorepo，降低构建和发布复杂度 |
| 状态管理/依赖装配 | Riverpod 3 + code generation，不默认引入 hooks | 异步状态、依赖覆盖与测试替身统一；官方 Riverpod 文档推荐 codegen |
| 路由 | `go_router` + `go_router_builder` 类型化路由 | Flutter 官方建议 Router 方案；生成器提供编译期参数检查 |
| HTTP | `dio` 封装在自有 Transport 接口后 | 需要拦截器、取消、超时和自定义适配，但禁止页面直接依赖 Dio |
| 安全存储 | `flutter_secure_storage` 封装在自有 SecureStore 后 | iOS Keychain/Android 加密存储；插件必须隔离以便测试和替换 |
| 可观测性 | 先定义 vendor-neutral ports | Sentry/Crashlytics 等供应商与账号尚未决定，业务层不得绑定 SDK |
| 测试 | `flutter_test` + SDK `integration_test`，平台插件全部包一层 | 官方测试分层；插件包装便于 Widget/单元测试替换 |

参考：[Riverpod getting started](https://riverpod.dev/docs/introduction/getting_started)、[go_router typed routes](https://pub.dev/packages/go_router_builder)、[Dio API](https://pub.dev/documentation/dio/latest/dio/)、[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)。依赖的精确版本在创建工程时由当前 SDK 解析并提交 `pubspec.lock`，不得使用无上限依赖或每次构建自动升级。

## 依赖方向

```text
app_bootstrap
  -> configuration + provider composition
  -> navigation
  -> session_persistence
  -> networking
  -> observability

feature presentation -> feature application -> feature domain
feature data -> networking/session ports -> core adapters
```

- 页面只依赖 feature application，不直接访问 Dio、secure storage、router 或厂商 SDK。
- `core` 提供端口和通用实现，不依赖任何具体业务 feature。
- 登录 feature 可以依赖 foundation 端口；foundation 不反向导入登录页面。

## 不采用的 V1 方案

- 不同时混用 Riverpod、BLoC、Provider 和 GetX。
- 不使用字符串 named routes 传递敏感参数。
- 不在 Dio interceptor 中无差别自动重试写请求或 K102。
- 不让 Widget 逐字段写 Keychain/Keystore。
- 不在首期拆成多个 Dart package/pub workspace；出现独立发布或编译边界需求后再评审。
- 不因本机曾安装 3.41.7 就创建落后于当前稳定线的新工程。

## 批准记录

用户于 2026-08-24 确认以下五项：

1. Flutter 跟随当前 stable 并固定为实际安装的 `3.47.1`，Android API 24、iOS 15 作为最低版本。
2. Riverpod 3 + codegen 作为唯一状态管理和依赖装配方案。
3. 使用 `go_router + go_router_builder`、`dio` 和 `flutter_secure_storage`，且全部通过自有端口隔离。
4. 可观测性首期保持供应商中立，后续再选 Sentry 或 Firebase Crashlytics。
5. 先建单一 App package，不启用 pub workspace。

## 本机环境验证

| 检查项 | 2026-08-24 结果 |
|---|---|
| Flutter | `3.47.1 stable`，framework `6655482ec0` |
| Dart / DevTools | `3.13.1 / 2.60.0` |
| Android SDK | `36.1`，JDK 21 可识别 |
| Android licenses | 尚有部分未接受；创建/构建 Android 工程前由用户执行 `flutter doctor --android-licenses` 并审阅接受 |
| iOS 工具链 | Windows 无法验证；后续必须在 macOS + Xcode 上完成真机构建门禁 |
| Windows 桌面工具链 | Visual Studio 未安装；本项目不以 Windows 桌面为目标，不阻塞移动端基线 |

ADR 已批准，但五个 foundation 模块完成详细评审前仍不运行 `flutter create`。
