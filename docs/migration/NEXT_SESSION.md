# 新会话接续说明

## 给新会话的首条指令

可以直接复制下面这段：

> 请先完整阅读 `C:\Users\Poplar\Desktop\KINGCLUB-APP-V2\docs\migration\README.md` 以及其中列出的全部迁移文档，再检查 `C:\Users\Poplar\Desktop\KingClub-app` 当前 Git 状态。以 `master / 505d222 / 1.1.37` 为稳定基线，不要恢复 `backup/ai-refactor-20260823` 的未完成首页重构。阅读完成后总结已确认决策、待确认问题和建议的下一步，不要立即大规模改代码。

## 必须阅读的文件

- `README.md`
- `CURRENT_STATE_AUDIT.md`
- `TARGET_ARCHITECTURE.md`
- `DATABASE_MIGRATION.md`
- `MIGRATION_PLAN.md`
- `DECISIONS_AND_OPEN_QUESTIONS.md`

## 开始工作前检查

在旧仓库执行只读检查：

```powershell
git branch --show-current
git rev-parse --short HEAD
git status --short
git log -3 --oneline --decorate
```

预期：

```text
branch: master
HEAD: 505d222
status: clean
```

如果状态不同，不要自行 reset；先说明差异并确认是否为用户的新改动。

## 重要分支

```text
master                         稳定版 1.1.37
backup/ai-refactor-20260823    未完成的 AI 重构备份
```

备份分支只用于参考模块化想法，不代表可运行版本。

服务端当前开发分支：

```text
ccsop-service/business/kingclub-v2             KingClub 独立服务实现
ccsop-property-identity-a033/feature/unified-identity-authority-v1
                                                物业统一身份权威接口功能分支
```

## 当前推荐下一步

资产盘点、统一身份契约、A033 幂等/并发/补偿/KYC 冲突、七个 K 接口密文主链、协议目录完整性、旧协议版本拒绝且不消耗短信 challenge、验证码与限流边界、Refresh Token 重用以及真实 WebSocket 撤销观测均已完成。服务端基线为 `business/kingclub-v2 / d9929ff`，物业身份基线为 `feature/unified-identity-authority-v1 / d8a9c18`；完整质量门禁分别为 37 文件/133 项和 190 文件/656 项测试。

四个 Flutter 登录页面已经归档到 `feature_login_session/pages/`，并全部达到 `Approved for Development`。ADR-0001 已批准，本机已升级到 Flutter `3.47.1 stable / Dart 3.13.1`。app_bootstrap、navigation、App Shell/信息架构和 Design System v1 已批准；业务深链和推送跳转仍须随各自页面单独评审。

用户已确认 Flutter 客户端采用全局门禁：本期全部功能/页面文档批准 → 全部 UI Mock → 整 App UI 流程验收 → 真实超级接口/WebSocket/SDK 接入。下一次继续：

1. 用户已于 2026-08-24 按建议确认 [48 页首发基线](../v2/scope/RELEASE_SCOPE_PROPOSAL.md)：46 页普通会员主体 + D4 私人储物柜 2 页。D1 完整群聊、D2 作品发布、D3 红包/金币转赠暂缓；角色后台移出消费者 App。M0 已冻结。
2. 48 个页面均已建立独立文档目录：四个登录页与 App Shell 已批准；navigation、Design System v1 和“四主目的地 + 中央扫码”已批准。Member Onboarding v1 的 KC-P-005～009 已完成产品、交互、状态、隐私、Fake 契约和验收文档，当前为 `In Review`。
3. 用户确认会员准入评审包后更新准入状态；随后按 home/profile → social/messaging → club/commerce → wallet/content 顺序逐项完成文档。networking、session/persistence、observability 只定义 App 端 port、Fake 和未来 adapter 契约。
4. 全部功能、页面和设计系统文档批准后，才运行 `flutter create` 并进入纯 UI/Mock 阶段。
5. UI Mock 覆盖整 App 并经用户验收达到 `UI Flow Approved` 后，才接真实超级接口、WebSocket、支付、推送等。
6. 发布前确认 applicationId/bundleId、域名、CI、Android 签名、Android licenses 和 macOS/Xcode/TestFlight 环境。

生产短信供应商、正式协议、生产服务凭据和 Flutter 客户端仍未验收。

## 工作纪律

- 旧版先建分支再改动。
- 一次只迁移一个业务模块。
- 支付、订单、聊天必须先补状态机和回归用例。
- 数据迁移必须提供校验和回滚脚本。
- 不把旧客户端传入的金额和用户身份当作可信数据。
- 不在同一阶段同时切换数据库、服务端接口和全部客户端。
