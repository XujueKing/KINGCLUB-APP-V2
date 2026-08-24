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

四个 Flutter 登录页面已经归档到 `feature_login_session/pages/`。启动鉴权页和手机号登录页已批准；验证码页完整评审稿已形成但仍为 `In Review`，协议确认页尚待正式评审。下一次继续：

1. 用户批准验证码页九项规则，重点确认 K102 发出后结果未知时重新获取验证码的 V1 失败关闭策略。
2. 批准后把验证码页更新为 `Approved for Development`。
3. 评审协议页是否仅在版本缺失/变化时独立展示。
4. 四页批准后建立 app_bootstrap、navigation、networking、session/persistence 和 observability 的独立 foundation 文档目录与 ADR。
5. foundation 文档批准后才创建 Flutter 工程和启动鉴权页代码。

生产短信供应商、正式协议、生产服务凭据和 Flutter 客户端仍未验收。

## 工作纪律

- 旧版先建分支再改动。
- 一次只迁移一个业务模块。
- 支付、订单、聊天必须先补状态机和回归用例。
- 数据迁移必须提供校验和回滚脚本。
- 不把旧客户端传入的金额和用户身份当作可信数据。
- 不在同一阶段同时切换数据库、服务端接口和全部客户端。
