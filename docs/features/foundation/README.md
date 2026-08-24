# Flutter Foundation 功能目录

- 总体状态：`In Review`
- 目标：在本期全部功能/页面文档完成前冻结跨功能底座边界、技术选型和 UI Mock 所需端口

## 本轮基础模块

1. [应用启动与环境](feature_app_bootstrap/README.md) — `Approved for Development`
2. [路由与导航](feature_navigation/README.md) — 详细设计已完成，`In Review`，待用户批准
3. [网络与超级接口传输](feature_networking/README.md)
4. [会话与安全持久化](feature_session_persistence/README.md)
5. [日志与可观测性](feature_observability/README.md)

跨模块选型见 [ADR-0001 Flutter Foundation 技术基线](../../v2/adr/0001_flutter_foundation_baseline.md)。

## 已确认事实

- 四个首批登录页面文档已全部达到 `Approved for Development`。
- ADR-0001 已批准；本机已升级并固定为 Flutter `3.47.1 stable / Dart 3.13.1`。
- Android SDK 36.1 与 JDK 21 已识别，但 Android licenses 尚未全部接受；iOS 工具链仍需在 macOS 上验证。
- 当前仓库不存在 `pubspec.yaml`、`lib/` 或 Android/iOS Flutter 工程，现阶段仍是文档评审。
- app_bootstrap 已于 2026-08-24 批准开发；navigation 已补齐路由目录、守卫、深链、生命周期和测试计划，当前只缺用户批准；其余三个 foundation 模块仍待详细设计。

## 开发准入

- 五个模块分别达到 `Approved for Development`。
- ADR-0001 的 SDK、平台下限、状态管理、路由、网络和安全存储选择已获得用户确认。
- 环境隔离、敏感信息、会话原子提交、路由守卫、重试与日志脱敏规则完成交叉验收。
- 五个 foundation 模块批准只代表底座文档门禁完成；仍须等待本期全部功能、页面和设计系统文档批准后，才能运行 `flutter create`，且创建工程本身必须作为独立、可验证提交。
- UI 阶段只接 Fake adapter；项目达到 `UI Flow Approved` 前不得连接真实超级接口、WebSocket 或生产 SDK。
