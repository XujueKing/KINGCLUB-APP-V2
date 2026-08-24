# KINGCLUB APP V2 Flutter 规划入口

更新时间：2026-08-24

## 目标

本目录定义 KingClub App V2 的 Flutter 总体架构、功能边界、实施顺序和文档先行规则。它是开发前的规划基线，不替代旧版审计与数据库迁移资料。

## 状态标签

所有关键结论必须使用以下标签之一：

- **已确认事实**：已从旧版源码、现有资料或用户指令确认。
- **当前建议**：当前阶段推荐采用，但可在评审后调整。
- **待用户决策**：会显著影响产品或技术方案，尚未获得确认。

## 必读顺序

1. [ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md)：Flutter V2 总体架构
2. [FEATURE_MAP.md](FEATURE_MAP.md)：业务域、功能与页面总览
3. [ROADMAP.md](ROADMAP.md)：分阶段建设路线
4. [DOCUMENTATION_FIRST_WORKFLOW.md](DOCUMENTATION_FIRST_WORKFLOW.md)：文档先行与开发准入规则
5. [../features/README.md](../features/README.md)：功能和页面文档目录规范
6. [BACKEND_FOUNDATION_PHASE.md](BACKEND_FOUNDATION_PHASE.md)：数据库、超级接口、登录鉴权与 WebSocket 第一阶段
7. [Flutter Foundation 功能目录](../features/foundation/README.md)：App 工程创建前的五个技术底座模块
8. [ADR-0001 Flutter Foundation 技术基线](adr/0001_flutter_foundation_baseline.md)：SDK、平台与核心依赖建议

首批页面评审入口：

1. [启动鉴权页](../features/identity/feature_login_session/pages/page_auth_bootstrap/README.md)
2. [手机号登录页](../features/identity/feature_login_session/pages/page_mobile_login/README.md)
3. [验证码页](../features/identity/feature_login_session/pages/page_sms_verification/README.md)
4. [协议确认页](../features/identity/feature_login_session/pages/page_terms_consent/README.md)

## 与迁移资料的关系

- 旧版现状与缺陷以 [迁移交接包](../migration/README.md) 为准。
- V2 架构与功能规划以本目录为准。
- 单个功能或页面的最终需求，以 `docs/features/<业务域>/<功能或页面>/` 内的评审文档为准。
- API v2 的 OpenAPI 契约完成后，应成为客户端接口字段的唯一事实来源。

## 当前总原则

- **已确认事实**：V2 使用 Flutter 建设 iOS/Android 客户端。
- **已确认事实**：旧版微信小程序继续承担稳定业务，并逐步接入 API v2。
- **当前建议**：Flutter 项目采用 feature-first、领域分块、分层依赖。
- **当前建议**：先完成一个可验证的纵向业务闭环，再扩展功能覆盖率。
- **已确认事实**：每个功能或页面必须有独立目录并先完成设计文档，之后才能开发。
