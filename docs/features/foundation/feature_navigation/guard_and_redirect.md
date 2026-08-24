# 会话守卫与重定向

- 文档状态：`Approved for Development`
- 输入：粗粒度 `SessionView` 与当前最小 RouteIntent

## 1. 纯决策边界

守卫只返回 `allow/hold/redirect/reject`，不得在 redirect/onEnter 回调里调用 K 接口、刷新 Token、清理 SecureStore、关闭 WebSocket、显示对话框或上报包含原始 URI 的日志。

```text
SessionCoordinator 完成副作用和状态转换
  -> NavigationRefreshPort 发出粗粒度状态版本
  -> GuardPolicy(sessionView, targetIntent)
  -> NavigationDecision
  -> NavigationCoordinator 串行执行一次
```

会话复核和刷新由 session 层 SingleFlight 完成；导航层只能在 `unknown/validating/refreshing` 时 hold 到 `/auth/bootstrap`，不能自行发请求。

## 2. 守卫矩阵

| SessionView | bootstrap | authFlow | onboarding/review | protected Shell |
|---|---|---|---|---|
| `unknown/validating/refreshing` | allow | hold | hold | hold |
| `anonymous` | redirect mobile | allow（上下文有效） | redirect mobile | redirect mobile |
| `authenticated + onboarding` | redirect currentStep | redirect currentStep | allow approved step | reject to currentStep |
| `authenticated + pending/rejected/suspended` | redirect review | redirect review | allow review | reject to review |
| `authenticated + approved` | redirect home | redirect home | reject to home | allow |
| `restricted` | redirect mobile notice | reject/redirect mobile | reject/redirect mobile | reject/redirect mobile |
| `revoked/expired` | hold，等待 session 层清理 | hold | reject | reject |

`revoked/expired` 不直接等同 anonymous：必须等 SessionCoordinator 阻止新请求、停止 realtime 重连并完成本地清理后，再发布 anonymous 和通用 notice。

## 3. NavigationDecision

```text
allow(target)
hold(bootstrapGeneration)
redirect(target, resetStack: bool)
reject(safeFallback, stableReason)
```

- 相同 session version + 相同 target 的决策必须确定且幂等。
- redirect 最多连续执行两次：一次会话分区调整、一次目标参数复核；超过预算进入安全 fallback 并记录稳定分类。
- redirect 不能返回当前完全相同的 location/state 形成循环。
- 守卫只用 RouteIntent 身份比较，不把 `$extra`、raw URI 或用户对象写入诊断。

## 4. 会话事件清栈

| 事件 | 前置副作用所有者 | 导航结果 |
|---|---|---|
| 登录成功且 K104 通过 | session/application | 按权威 membership reset 到 currentStep、review 或 home |
| 主动本地退出完成 | session/realtime | `reset` 到 mobile，可带远端结果未知通用 notice |
| 新设备顶号/撤销 | session/realtime | `reset` 到 mobile，notice=`signedInElsewhere|sessionRevoked` |
| Refresh Token 重用 | session/realtime | `reset` 到 mobile，notice=`securitySessionReset` |
| 访问/Refresh 到期 | session | `reset` 到 mobile，notice=`sessionExpired` |
| 账号 disabled/deleted/merged | session/identity | 清除认证栈并 `reset` 到 mobile，notice=`accountUnavailable` |
| 成员 suspended/rejected | session/identity | 清除普通业务栈并 `reset` 到 mobile，notice=`membershipUnavailable`；后续状态页另立文档 |

notice 只允许稳定枚举，禁止携带服务端 message、手机号、账号、sessionId 或 requestId。

## 5. 后续扩展门禁

当前不实现 `PendingIntentStore`、通用 restricted 路由或任意业务对象路由。将来某个订单、聊天或其他页面完成独立文档和 UI Mock 后，再为该具体页面增加 RouteIntent、守卫和对象级权限测试；不预建通用框架。
