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

资产盘点、统一身份契约、A033 隔离联调和登录/会话服务端骨架已完成。服务端当前基线为 `business/kingclub-v2 / c21d9bc`。下一次工作继续从已批准的[登录、鉴权与会话文档](../features/identity/feature_login_session/README.md)进入完整链路验收：

1. 建立仅用于测试的 mock 短信路由、published 协议和隔离账号夹具，不把真实手机号、凭据或正式协议正文提交 Git。
2. 通过真实 ECDH 握手调用 `K260824000101`～`K260824000103`，再用签发的 Session/API Key 调用 `K260824000104`～`K260824000106`。
3. 将物业身份服务加入测试编排，覆盖首次取号/占位、再次登录本地投影命中、权威不可用、幂等补偿和绑定冲突。
4. 补齐参数错误、权限拒绝、重放、限流、并发刷新、单设备互踢和 WebSocket 撤销的 HTTP/双服务自动化矩阵。
5. 上述验收通过后，再建立启动鉴权页、手机号登录页、验证码页和协议确认页各自的独立页面文档目录；文档批准前不创建 Flutter 页面代码。

服务端验收前不创建 Flutter 登录页面；页面还需分别建立独立目录并完成页面规格。

## 工作纪律

- 旧版先建分支再改动。
- 一次只迁移一个业务模块。
- 支付、订单、聊天必须先补状态机和回归用例。
- 数据迁移必须提供校验和回滚脚本。
- 不把旧客户端传入的金额和用户身份当作可信数据。
- 不在同一阶段同时切换数据库、服务端接口和全部客户端。
