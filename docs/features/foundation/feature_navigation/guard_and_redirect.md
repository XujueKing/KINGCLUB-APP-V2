# 会话守卫与重定向

- 文档状态：`In Review`
- 输入：粗粒度 `SessionView`、目标 RouteIntent、一次性 pending intent

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

| SessionView | bootstrap | public | authFlow | protected | restricted |
|---|---|---|---|---|---|
| `unknown/validating/refreshing` | allow | hold | hold | hold | hold |
| `anonymous` | redirect mobile | allow | allow（上下文有效） | 保存安全 pending intent 后 redirect mobile | reject/redirect mobile |
| `authenticated` | redirect pending 或 home | allow | redirect pending 或 home | allow，并由目标 Repository 继续对象级鉴权 | reject/redirect home |
| `restricted` | redirect restricted intent | allow（仅 allowlist） | reject | reject | allow（仅 allowlist） |
| `revoked/expired` | hold，等待 session 层清理 | allow（仅 allowlist） | hold | reject | hold |

`revoked/expired` 不直接等同 anonymous：必须等 SessionCoordinator 阻止新请求、停止 realtime 重连并完成本地清理后，再发布 anonymous 和通用 notice。

## 3. NavigationDecision

```text
allow(target)
hold(bootstrapGeneration)
redirect(target, resetStack: bool, consumePending: bool)
reject(safeFallback, stableReason)
```

- 相同 session version + 相同 target 的决策必须确定且幂等。
- redirect 最多连续执行两次：一次会话分区调整、一次目标参数复核；超过预算进入安全 fallback 并记录稳定分类。
- redirect 不能返回当前完全相同的 location/state 形成循环。
- 守卫只用 RouteIntent 身份比较，不把 `$extra`、raw URI 或用户对象写入诊断。

## 4. 会话事件清栈

| 事件 | 前置副作用所有者 | 导航结果 |
|---|---|---|
| 登录成功且 K104 通过 | session/application | `reset` 到一次 pending intent；没有则 home |
| 主动本地退出完成 | session/realtime | `reset` 到 mobile，可带远端结果未知通用 notice |
| 新设备顶号/撤销 | session/realtime | `reset` 到 mobile，notice=`signedInElsewhere|sessionRevoked` |
| Refresh Token 重用 | session/realtime | `reset` 到 mobile，notice=`securitySessionReset` |
| 访问/Refresh 到期 | session | `reset` 到 mobile，notice=`sessionExpired` |
| 账号 disabled/deleted/merged | session/identity | 清除认证栈，进入未来批准的 restricted/manual route；未实现前安全回 mobile |
| 成员 suspended/rejected | session/identity | `reset` 到 restricted allowlist；不得进入普通 protected |

notice 只允许稳定枚举，禁止携带服务端 message、手机号、账号、sessionId 或 requestId。

## 5. Pending RouteIntent

- 同一进程最多保存一个待登录目标，仅在合法 protected 深链/推送或用户主动打开受保护功能时建立。
- 存储在内存 `PendingIntentStore`，不进入 URI、SharedPreferences、SecureStore 或 Router restoration。
- 登录成功后先重新校验 route allowlist、参数 schema、TTL 和当前权限，再原子消费；无论成功或拒绝都只能消费一次。
- 登录失败、用户取消、流程 generation 销毁、退出或超过 TTL 时清除。
- 恶意/未知目标不得覆盖已有合法 pending intent；冷启动阶段采用第一个通过校验的目标，消费前的重复事件只去重。

## 6. 对象级权限

路由守卫只确认会话分区，不能证明用户有权查看某个订单、会话或用户资料。目标页面 Repository 必须让服务端按当前会话执行对象级鉴权；页面参数中的资源 ID 永远不是授权证据。
