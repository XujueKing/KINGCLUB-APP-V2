# Flutter Foundation 功能目录

- 总体状态：`Approved for Development`
- 目标：在本期全部功能/页面文档完成前冻结跨功能底座边界、技术选型和 UI Mock 所需端口

## 本轮基础模块

1. [应用启动与环境](feature_app_bootstrap/README.md) — `Approved for Development`
2. [路由与导航](feature_navigation/README.md) — `Approved for Development`
3. [网络与超级接口传输](feature_networking/README.md) — `Approved for Development`
4. [会话与安全持久化](feature_session_persistence/README.md) — `Approved for Development`
5. [日志与可观测性](feature_observability/README.md) — `Approved for Development`

M0 全局 UI 基线模块：

6. [设计系统](feature_design_system/README.md) — `Design System v1` 已批准
7. [App Shell 与全局信息架构](feature_app_shell/README.md) — `Shell IA/Wireframe v1` 已批准
8. [Mock Runtime](feature_mock_runtime/README.md) — `Approved for Development`
9. [原生能力与权限](feature_native_capabilities/README.md) — `Approved for Development`

跨模块选型见 [ADR-0001 Flutter Foundation 技术基线](../../v2/adr/0001_flutter_foundation_baseline.md)。

## 已确认事实

- 四个首批登录页面文档已全部达到 `Approved for Development`。
- ADR-0001 已批准；本机已升级并固定为 Flutter `3.47.1 stable / Dart 3.13.1`。
- Android SDK 36.1 与 JDK 21 已识别，但 Android licenses 尚未全部接受；iOS 工具链仍需在 macOS 上验证。
- Flutter 3.47.1 的 Android/iOS 工程、`pubspec.yaml` 与 `lib/` 已于 2026-08-26 创建；当前只包含 UI、类型化路由和 Fake，不含真实 adapter。
- app_bootstrap、navigation、networking、session/persistence、observability、Design System、App Shell、Mock Runtime 和原生能力均已达到 `Approved for Development`；48 页导航语义库存已冻结并全部批准。

## 开发准入

- 九个模块均达到 `Approved for Development`。
- ADR-0001 的 SDK、平台下限、状态管理、路由、网络和安全存储选择已获得用户确认。
- 环境隔离、敏感信息、会话原子提交、路由守卫、重试与日志脱敏规则完成交叉验收。
- Foundation 批准只代表底座文档门禁完成；本期全部功能、页面和设计系统文档也已于 2026-08-26 完成准入，现在可以把 `flutter create` 作为独立、可验证步骤进入 UI/Mock 阶段。
- UI 阶段只接 Fake adapter；项目达到 `UI Flow Approved` 前不得连接真实超级接口、WebSocket 或生产 SDK。
