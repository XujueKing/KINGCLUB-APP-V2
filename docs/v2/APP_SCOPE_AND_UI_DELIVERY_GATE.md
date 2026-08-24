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

| 业务域 | 当前事实 | 下一文档动作 |
|---|---|---|
| foundation | ADR 与 app_bootstrap 已批准；navigation 精简稿待批准；其余三个模块待详细设计 | 完成 foundation 和 design system 文档 |
| identity/login | 启动鉴权、手机号、验证码、协议确认四页已批准 | 复核是否还有实名、资料初始化、安全/注销等本期页面 |
| home | 只有 `/home` 目标语义，尚无页面目录 | 冻结首页功能和页面清单 |
| social | 候选范围存在，未冻结本期页面 | 逐功能/页面立项 |
| messaging | 候选范围存在，未冻结本期页面 | 逐功能/页面立项，不预建聊天路由 |
| content | 候选范围存在，未冻结本期页面 | 逐功能/页面立项 |
| club | 候选范围存在，未冻结本期页面 | 逐功能/页面立项 |
| commerce | 候选范围存在，未冻结本期页面 | 逐功能/页面立项，不预建订单路由 |
| membership_wallet | 候选范围存在，未冻结本期页面 | 逐功能/页面立项 |
| profile_settings | 候选范围存在，未冻结本期页面 | 逐功能/页面立项 |
| operations | 默认不进入首期，仍须由用户最终确认 | 确认排除或纳入并记录理由 |

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
