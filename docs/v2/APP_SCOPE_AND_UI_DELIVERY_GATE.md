# App 范围、页面覆盖与 UI 交付门禁

- 文档状态：`In Review`
- 决策日期：2026-08-24
- 作用：作为本期 Flutter App 是否允许进入 UI、是否允许真实接入的唯一覆盖账本

## 1. 已确认交付顺序

```text
冻结本期功能/页面总清单
  -> 每个功能和页面独立文档批准
  -> 创建 Flutter UI，只接 Mock/Fake
  -> 模拟本期整 App 主流程、异常流程和返回路径
  -> 用户完成 UI 验收，项目标记 UI Flow Approved
  -> 按批准契约接真实超级接口、WebSocket 和 SDK
```

禁止事项：

- 不允许页面文档未批准就创建 UI。
- 不允许因为某一个页面已批准就提前开始整 App UI。
- 不允许 UI 阶段访问真实开发、测试或生产服务。
- 不允许单个页面 Mock 完成后提前连接真实接口。
- 不允许用真实接口返回反向决定 UI、状态机或页面流程。

## 2. 覆盖账本字段

本期范围冻结后，每个功能和页面都必须进入账本：

| 字段 | 说明 |
|---|---|
| `scopeId` | 稳定功能/页面编号 |
| `domain` | foundation、identity、home、social 等业务域 |
| `featureDoc` | 独立功能目录链接 |
| `pageDoc` | 独立页面目录链接；功能级能力可为空 |
| `inReleaseScope` | 是否纳入本期，退出范围必须记录原因 |
| `docStatus` | Draft / In Review / Approved for Development |
| `designVersion` | UI 设计稿或线框版本 |
| `mockScenarios` | Mock/Fake 场景编号与覆盖状态 |
| `uiStatus` | Not Started / UI Mock Implemented / UI Flow Approved |
| `integrationStatus` | Blocked / Integrated / Implemented / Accepted |

## 3. 当前覆盖状态

旧版 69 个物理路由已经完成逐项审计，详见 [本期范围评审包](scope/README.md)。当前形成“46 个普通会员首发逻辑页面 + 11 个可选包页面 + 角色后台/旧平台排除项”的提案，但仍需用户确认可选包和角色边界，因此 M0 范围尚未冻结。

| 业务域 | 当前事实 | 下一文档动作 |
|---|---|---|
| foundation | ADR 与 app_bootstrap 已批准；navigation 精简稿待批准；其余三个模块待详细设计 | 完成 foundation 和 design system 文档 |
| identity/login | 四个登录页面已批准；另提议实名、形象资料、两步偏好和审核状态 | 确认 9 页身份范围后逐页立项 |
| home | 提议首页、扫码分流和 App Shell | 确认后建立首页与扫码文档 |
| social | 提议通讯录、好友申请、统一用户主页、备注、权限和黑名单共 8 页 | 确认后逐页立项 |
| messaging | 提议首发 5 页稳定单聊；完整群聊另列 D1 | 决定 D1 后冻结消息页数 |
| content | 提议短视频浏览首发；作品发布另列 D2 | 决定 D2 |
| club | AA、VIP 组局和入场共 7 页；私人储物柜 2 页另列 D4 | 决定 D4 |
| commerce | 提议点单、确认、订单中心、详情和支付共 5 页 | 确认消费者订单边界 |
| membership_wallet | 提议资产流水首发；红包与金币转赠 2 页另列 D3 | 决定 D3 |
| profile_settings | 提议我的、编辑资料、二维码、设置、支付安全、注销、关于/协议等 7 页 | 确认账号绑定不进首发 |
| operations | 17 个旧管理/技术路由建议不进入消费者首发 | 用户确认角色后台全部移出 |

当前不能标记“文档范围完成”，也不能开始 UI。

## 4. 进入 UI 的全局条件

- 本期功能/页面清单和不做清单由用户确认。
- 账本中所有 `inReleaseScope=true` 项都有独立目录和可执行验收文档。
- 所有这些项的 `docStatus=Approved for Development`。
- design system、foundation、跨页面导航和 Mock 数据契约已批准。
- 仓库审计不存在未登记页面或功能入口。

满足后才允许执行 `flutter create` 并进入纯 UI/Mock 阶段。

## 5. 进入真实接入的全局条件

- 所有本期页面达到 `UI Mock Implemented`。
- 启动、登录、首页及本期全部业务主流程和异常流程可离线完整演示。
- 用户完成整 App UI 验收并明确批准项目状态 `UI Flow Approved`。
- UI 验收差异已经回写功能/页面文档和 Mock 契约。
- 真实接入计划明确 adapter 替换顺序、测试、灰度和回滚方式。

任一条件缺失时，networking、WebSocket、支付、推送等只能保留端口、Fake 和契约文档，不得连接真实环境。

## 6. 变更控制

- 新增页面必须先加入本期清单并完成文档，不能在 UI 开发中临时增加。
- 删除/合并页面必须记录用户任务去向和导航影响。
- UI Mock 验收后新增功能会撤销当前 `UI Flow Approved`，直到新增范围完成同样流程。
- 真实接入发现契约缺口时回到文档/Mock 阶段修正，不能在 adapter 中偷偷改变页面语义。
