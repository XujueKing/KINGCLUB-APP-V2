# 路由与导航

- Scope ID：`KC-F-002`

- 文档状态：`Approved for Development`
- 优先级：P0
- 已确认技术：`go_router + go_router_builder` 类型化路由

## 目标

当前阶段统一启动、登录四页、会员准入、App Shell、五个主目的地、全局返回栈和会话失效。页面只能表达导航意图，不拼接 URI、不直接读取会话存储。其余业务页面先在 M0 库存中保留语义名，只有独立页面文档批准后才分配最终 location 和参数契约。

## 路由分区

| 分区 | 示例 | 规则 |
|---|---|---|
| bootstrap | `/auth/bootstrap` | 唯一冷启动入口，不可被深链直接打开 |
| auth flow | `/auth/mobile|code|consent` | 敏感上下文只用内存 flowId，禁止系统恢复和外部深链 |
| onboarding | `/onboarding/*` 目标语义 | authenticated 但会员准入未完成；具体步骤按 KC-P-005～009 文档 |
| protected shell | `/home|messages|discover|me` 目标语义 | 必须经过已复核 SessionState 与 approved membership；页面批准前不得实现 |

## 当前设计

- 使用生成的 RouteData，公开 path/query 参数必须是非敏感、可验证值。
- 手机号、challenge、验证码、协议快照、Token 和任意用户对象不得进入 URI；只传不可猜测、进程内有效的 flowId。
- 当前 UI Mock 登录完成后按会员状态进入 onboarding/review 或 Shell 首页语义，`returnTo` 保持为空；以后只有目标页面文档和 UI 均批准后才能加入 RouteIntent allowlist。
- redirect 只读取已解析的粗粒度 SessionState，不在 redirect 回调里发网络请求或执行注销副作用。
- 会话撤销、过期或账号不可用由统一导航协调器 reset 到手机号页并显示通用说明；当前不建设通用 `restricted` 路由体系。
- 未知路由和非法参数进入安全根目标，不回显原始参数。

登录流程的 `loginFlowId` 使用类型化 `$extra` 关联进程内 FlowStore，不进入 location。外部链接、进程恢复或缺少合法 `$extra` 直接打开 `/auth/code|consent` 时必须拒绝并安全回到 `/auth/mobile`。

## 返回与生命周期

- 登录流程使用受控 replace 栈，成功后不能返回验证码或协议确认页。
- Android predictive back 使用当前 Flutter/Router 支持方式统一测试；重要退出动作由页面意图确认，不依赖已弃用 API。
- auth flow 永不进行进程恢复。
- 当前 UI Mock 不启用 App Link、推送跳转或业务 `returnTo`；对应页面文档和 UI 流程批准后再逐项目启用。
- 首个移动端版本不启用 Router 路由树状态恢复；所有冷启动从 `/auth/bootstrap` 重新复核。普通页面恢复必须在对应页面文档批准后加入 allowlist。

官方依据：[go_router type-safe routes](https://pub.dev/documentation/go_router/latest/topics/Type-safe%20routes-topic.html)、[go_router_builder `$extra`](https://pub.dev/packages/go_router_builder)、[go_router state restoration](https://pub.dev/documentation/go_router/latest/topics/State%20restoration-topic.html)。精确依赖版本在创建工程时由 Flutter 3.47.1 解析并锁定。

## 交付状态

- **已确认事实**：ADR-0001 已批准类型化 go_router，app_bootstrap 已批准 `/auth/bootstrap` 为正式 App Root 唯一初始位置。
- **当前建议**：采用本目录的最小路由目录、纯守卫决策、内存登录 Flow 和 V1 禁用 Router 栈恢复方案；深链/推送仅保留安全准入规则，不激活目标。
- **已确认事实**：用户于 2026-08-25 确认继续采用本模块与 Shell IA v1；未来业务路由仍需各自页面文档批准。

## 配套文档

- [V1 路由目录与导航动作](route_catalog.md)
- [M0 48 页路由语义库存](m0_route_inventory.md)
- [会话守卫与重定向](guard_and_redirect.md)
- [深链、推送与 returnTo 契约](deep_link_contract.md)
- [返回栈、生命周期与恢复](lifecycle_and_back.md)
- [测试计划](test_plan.md)
- [验收标准](acceptance.md)
- [Foundation 索引](../README.md)
