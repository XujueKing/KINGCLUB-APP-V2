# 统一账号与登录基础 migration 实施清单

- 文档状态：Approved for Development
- 原则：先物业权威接口，后 KingClub 本地登录；禁止直接修改已执行 migration

## 1. 分支策略

```text
business/zhuzhou-property-regulation-v1
  `-- feature/unified-identity-authority-v1   物业权威能力

main / f543854
  `-- business/kingclub-v2                   KingClub 独立实例
```

物业功能分支必须在当前已部署业务分支最新提交上创建，不直接在部署分支开发。KingClub 继续使用现有 `business/kingclub-v2`。

## 2. 物业侧 migration 组

**已确认事实**：功能分支已从部署业务分支基线创建，最终分配 migration `325` 和 `326`。

### P-A 服务凭据基础

新增：

- `serviceClientCredential`：服务客户端、来源业务线、宿主机密钥引用、版本、状态、到期和允许接口；数据库不保存密钥原文或可逆密文。
- `serviceClientAccessAudit`：认证成功/失败、请求摘要、来源、接口和结果。

同时完成表目录登记、敏感等级、双语 COMMENT 和密钥轮换测试。真实服务密钥只通过部署配置/安全初始化写入，不进入 migration。

### P-B 统一账号来源与版本

扩展：

- `userAccount.originAppCode`：property/kingclub/legacy/import。
- `userAccount.identityVersion`：统一身份事实版本，初始为 1。
- `userKyc.sourceAppCode`、`verificationPurposeCode`、`consentRecordId`。

现有数据使用受控 `legacy` 或 `property` 回填；不得凭空把 KYC 标记为 verified。

### P-C Provisioning 幂等与身份 Outbox

新增：

- `identityProvisioningRequest`：服务客户端 + App + 幂等键唯一，请求摘要和结果。
- `identityEventOutbox`：账号创建、冻结、恢复、归并、登录身份变化和 KYC 摘要变化。

通用消息通知 Outbox 不替代身份事实 Outbox。

### P-D 权威 Routine

新增 `identity_resolve_or_create_account(IN p_input JSON)`：

- 仅由 internal identity executor 调用。
- 使用 `getGenerateId('U')` 发号。
- 原子处理幂等、手机号唯一绑定、账号状态、KYC 占位/摘要、审计和 Outbox。
- 登记到 `databaseRoutineCatalog`，版本从 1 开始。

### P-E 内部超级接口

- 新增平台内部身份分类节点和接口元数据。
- `executorType=internal`，专用 adapterKey，`authPolicy=system`。
- 完整登记 `interfaceKey`、`interfaceReturn`、权限、敏感等级、超时和开发者可见性。
- 修改 `/supper-interface` 安全入口，支持服务凭据解密后建立 `authMode=system`。

## 3. KingClub 侧 migration 组

KingClub 当前基线最大 migration 为 017，实际开发按依赖连续编号。

### K-A KingClub 业务线与短信基础

- 注册 `kingclub` 业务线和独立适配器配置。
- 迁移通用短信供应商、场景路由、挑战和发送审计表。
- 使用 KingClub 独立供应商凭据、Redis namespace 和限流配置。

### K-B 统一账号本地投影

新增/扩展：

- `userAccount` 本地投影字段：authoritySource、identityVersion、lastSyncedDate。
- `kingclubMember`、`kingclubProfile`。
- `identityProvisioningAttempt`、`identitySyncInbox`。
- `legacyIdentityMap`、consent 和 device 表。

本库不执行 `getGenerateId('U')` 创建用户。

### K-C Session 与单设备

- 增加 Refresh Token 当前/上一版本和轮换时间。
- 活动 Session/API Key 唯一范围改为 `userAccount + clientAppCode=kingclub`。
- 增加 new_device_login、refresh_reuse_detected、account_frozen、identity_merged 撤销原因。

### K-D 登录 Routine 与接口

- 发送验证码。
- 短信登录：验证挑战 → 调物业权威接口 → KingClub 本地成员/会话事务。
- Refresh、me、logout、revoke_others。
- 登记 `K260824000101`～`K260824000106` 及分类树、Routine 目录和接口契约。

### K-E 身份事件与 WebSocket

- 幂等消费物业身份 Outbox 事件。
- 冻结/归并后撤销 KingClub Session/API Key。
- 发布 `auth.session.revoked` 并跨实例关闭旧 WebSocket。

## 4. 代码变更清单

### 物业功能分支

- 增加 Service Credential store、请求解密和防重放。
- 扩展 `SuperInterfaceExecutionContext`：serviceClientId/sourceBusinessLine。
- 增加 Internal Identity Executor 和 Repository。
- 增加 system auth 正常、拒绝、重放、轮换和日志脱敏测试。

### KingClub 分支

- 增加 Property Identity Authority Client，严格设置超时、幂等和错误映射。
- 从物业实现中选择性迁移 SMS、mobile crypto、refresh 和测试模式。
- 拆分 KingClub Auth Executor，不复制物业 Web/QR/房屋初始化逻辑。
- 增加账号投影、成员、Session 和身份 Inbox Repository。

## 5. 验证矩阵

| 场景 | 物业结果 | KingClub 结果 |
|---|---|---|
| 新手机号首次注册 | 创建一个 U 和占位 | 创建成员并签发会话 |
| 已有物业用户注册 KingClub | 返回原 U | 新建 KingClub 成员 |
| KingClub 先注册后物业注册 | 复用原 U，补物业成员 | 不受影响 |
| 两个 KingClub 请求并发注册 | 只创建一个 U | 只保留一个活动会话 |
| 物业成功、KingClub 超时 | 幂等返回原 U | 重试完成本地事务 |
| 手机号/KYC 冲突 | 不自动合并 | 不签发会话，进入人工处理 |
| 账号冻结/归并 | 写 Outbox | 撤销会话并关闭 WebSocket |
| 物业身份服务不可用 | 不产生新 U | 返回可重试错误，不本地发号 |

## 6. 发布顺序

1. 物业功能分支 migration 和单元/集成测试。
2. 测试环境部署物业 system auth 与统一账号接口。
3. 使用伪造测试身份完成并发、幂等、冲突和回滚验证。
4. KingClub migration、内部客户端和登录测试。
5. 两服务测试环境端到端联调。
6. 先发布物业向后兼容能力，再发布 KingClub。
7. 监控 provisioning 失败、冲突、Outbox 延迟和重复账号指标。

## 7. 回滚边界

- 物业新列和新表保持向后兼容，不在同版本删除旧字段/Routine。
- 关闭内部接口只阻止新的 KingClub 首次注册，不删除已创建的统一账号。
- KingClub 可关闭短信登录入口，已有会话按安全策略继续或统一撤销。
- 已分配 `U...` 永不回收；失败占位通过状态和审计处理，不重用编号。

## 8. 开发准入

- [x] 内部接口契约 Approved for Development
- [x] KYC V1 最小写入边界确认：不传证件图片、人脸或活体材料
- [x] 服务凭据方案确认：专用凭据 + 加密超级接口 + 防重放 + 轮换
- [x] 物业最新 migration 编号重新检查并分配：325/326
- [ ] 两个分支的测试环境和数据库账号准备完成
- [ ] 回滚开关、告警和人工冲突处理责任人确认

## 9. 当前实现记录

- 物业功能分支：`feature/unified-identity-authority-v1`。
- 服务鉴权提交：`62e48b1`。
- 身份权威提交：`fc7911e`。
- 已登记内部接口：`S260824000401`。
- 静态/代码验证：189 个测试文件、653 项测试及 `npm run verify` 通过。
- KingClub 调用端与本地投影已在 `business/kingclub-v2` 提交并推送 `dd0f048`；包含 migration `018`，但尚未实迁。
- 未完成：测试数据库实迁、真实服务凭证初始化和跨服务 A033 联调。
