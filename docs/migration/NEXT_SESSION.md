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

资产盘点、统一身份契约、A033 隔离联调、六个 K 接口密文主链、并发权威开户、物业不可达失败关闭和本地提交补偿已完成。服务端基线为 `business/kingclub-v2 / e086ae1`，已实迁至 migration 021，完整质量门禁为 34 个测试文件、126 项测试。下一次继续补异常矩阵：

1. 设计不含真实实名资料的身份绑定/KYC 冲突隔离数据并验证错误映射。
2. 覆盖验证码错误/超时以及手机号、设备、IP 限流边界。
3. 覆盖 Refresh Token 并发宽限期外重用并确认会话撤销。
4. 使用真实 WebSocket 客户端观测旧设备收到 `auth.session.revoked` 后被关闭。
5. 异常矩阵通过后，分别建立启动鉴权页、手机号登录页、验证码页和协议确认页的独立页面文档目录；文档批准前不创建 Flutter 页面代码。

生产短信供应商、正式协议、生产服务凭据和 Flutter 客户端仍未验收。

## 工作纪律

- 旧版先建分支再改动。
- 一次只迁移一个业务模块。
- 支付、订单、聊天必须先补状态机和回归用例。
- 数据迁移必须提供校验和回滚脚本。
- 不把旧客户端传入的金额和用户身份当作可信数据。
- 不在同一阶段同时切换数据库、服务端接口和全部客户端。
