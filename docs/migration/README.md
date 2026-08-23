# KINGCLUB APP V2 迁移交接包

更新时间：2026-08-24  
维护人：poplar `<3156506895@qq.com>`

## 文档用途

本目录用于保存 KingClub 现状审计、V2 架构决策和迁移计划，使后续新的 Codex/ChatGPT 会话能够直接读取文档并继续工作，不必重新分析整个旧项目。

## 现有项目基线

- 旧项目目录：`C:\Users\Poplar\Desktop\KingClub-app`
- 当前稳定分支：`master`
- 当前稳定提交：`505d22248a8f711791cabe1805a8240b7fda4ffb`
- 提交说明：`1.1.37`
- 当前工作区：审计完成时为干净状态
- AI 未完成重构备份分支：`backup/ai-refactor-20260823`
- AI 重构备份提交：`dc1a086`
- 额外副本备份：`C:\Users\Poplar\Desktop\KingClub-app-AI-copy-20260823`

不要在没有逐项迁移和回归验证的情况下，把 `backup/ai-refactor-20260823` 的首页整体覆盖回 `master`。

## 已形成的方向性结论

1. `1.1.37` 保持为微信小程序生产基线，采用小步修复和模块化。
2. 不继续把微信小程序代码作为 iOS/Android 长期客户端架构。
3. iOS/Android V2 建议使用 Flutter 独立开发。
4. Flutter 与微信小程序共享 API、数据模型和业务规则，不强求共享 UI 源码。
5. 服务端先建设 API v2，再逐步迁移客户端。
6. 数据采用“共享身份 + 可选共享同城社交域 + 各 App 独立业务域”。
7. 先做逻辑隔离，可以暂时共用数据库实例；以后再按需要物理分库。
8. 不同时全量重写小程序、Flutter、服务端和数据库。

## 推荐阅读顺序

1. [NEXT_SESSION.md](NEXT_SESSION.md)——新会话首先读取
2. [CURRENT_STATE_AUDIT.md](CURRENT_STATE_AUDIT.md)——旧版项目现状与缺陷
3. [TARGET_ARCHITECTURE.md](TARGET_ARCHITECTURE.md)——V2 目标架构
4. [DATABASE_MIGRATION.md](DATABASE_MIGRATION.md)——数据拆分与迁移设计
5. [MIGRATION_PLAN.md](MIGRATION_PLAN.md)——分阶段实施计划
6. [DECISIONS_AND_OPEN_QUESTIONS.md](DECISIONS_AND_OPEN_QUESTIONS.md)——已定事项和待确认问题

## 下一步最合理的工作

登录/统一身份的数据库、超级接口、隔离密文主链和异常矩阵已经完成。启动鉴权页、手机号登录页、验证码页和协议确认页已分别建立 `docs/features/identity/feature_login_session/pages/page_*` 目录；启动鉴权页规格已批准。

下一步按 [NEXT_SESSION.md](NEXT_SESSION.md) 逐页确认交互与视觉方向；页面状态改为 `Approved for Development` 前不创建对应 Flutter 实现。
