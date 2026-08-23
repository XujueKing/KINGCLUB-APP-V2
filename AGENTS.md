# KINGCLUB APP V2 Agent Instructions

开始任何分析、设计或代码工作前，必须完整阅读：

1. `README.md`
2. `NEXT_SESSION.md`
3. `CURRENT_STATE_AUDIT.md`
4. `TARGET_ARCHITECTURE.md`
5. `DATABASE_MIGRATION.md`
6. `MIGRATION_PLAN.md`
7. `DECISIONS_AND_OPEN_QUESTIONS.md`

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

