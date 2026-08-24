# KINGCLUB APP V2 Agent Instructions

开始任何分析、设计或代码工作前，必须完整阅读：

1. `docs/migration/README.md`
2. `docs/migration/NEXT_SESSION.md`
3. `docs/migration/CURRENT_STATE_AUDIT.md`
4. `docs/migration/TARGET_ARCHITECTURE.md`
5. `docs/migration/DATABASE_MIGRATION.md`
6. `docs/migration/MIGRATION_PLAN.md`
7. `docs/migration/DECISIONS_AND_OPEN_QUESTIONS.md`

进行 Flutter V2 的产品、设计或开发工作前，还必须完整阅读：

1. `docs/v2/README.md`
2. `docs/v2/ARCHITECTURE_OVERVIEW.md`
3. `docs/v2/FEATURE_MAP.md`
4. `docs/v2/ROADMAP.md`
5. `docs/v2/DOCUMENTATION_FIRST_WORKFLOW.md`
6. `docs/v2/BACKEND_FOUNDATION_PHASE.md`
7. `docs/v2/APP_SCOPE_AND_UI_DELIVERY_GATE.md`

任何功能或页面都必须先在 `docs/features/` 下建立独立目录并完成设计文档。未达到文档准入条件时，不得在 `lib/` 下创建对应实现。

Flutter App 必须执行以下全局交付门禁：

1. 先冻结本期 App 功能与页面总清单。
2. 清单内每个功能和页面分别建立目录、完成设计文档并获得批准。
3. 文档批准后只允许开发 UI 和 Mock/Fake 数据流程；不得连接真实超级接口、WebSocket、支付、推送或其他生产 SDK。
4. 使用 Mock/Fake 把本期 App 的全部页面、主流程、异常流程和返回路径完整模拟并完成 UI 验收。
5. 只有全局 UI Mock 流程验收通过后，才允许按批准契约接入真实接口和 SDK。

`Approved for Development` 对 App 页面只表示允许进入 UI/Mock 阶段，不等于允许真实服务接入。真实接入必须同时满足项目级 `UI Flow Approved` 门禁。

旧版源码位于 `C:\Users\Poplar\Desktop\KingClub-app`。

旧版稳定基线应为：

- 分支：`master`
- 提交：`505d222`
- 版本：`1.1.37`

在修改旧版前必须先检查 Git 状态。发现与上述基线不同或存在用户改动时，不得 reset、checkout 或删除，必须先向用户说明。

`backup/ai-refactor-20260823` 是未完成的 AI 重构备份，只能作为参考，不得整体覆盖稳定版。

V2 默认方向：

- 微信小程序在稳定版上渐进维护
- iOS/Android 使用 Flutter 新建客户端
- 服务端建设 API v2
- 数据采用共享身份、可选共享同城社交域、各 App 独立业务域
- 先逻辑隔离，后按需要物理分库
- 避免同时全量重写客户端、服务端和数据库

任何架构建议必须明确标记为“已确认事实”“当前建议”或“待用户决策”。
