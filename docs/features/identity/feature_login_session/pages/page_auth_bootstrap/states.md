# 启动鉴权页状态与错误映射

## 1. 单一状态模型

页面只订阅登录功能 application 层的启动恢复状态，不自行保存第二套认证状态。建议页面状态为不可变联合类型：

| 页面状态 | 含义 | 允许的下一状态 |
|---|---|---|
| `initializing` | 初始化运行环境、设备实例和安全存储 | `validating`、`refreshing`、`routingAnonymous`、`fatal` |
| `validating` | 使用仍有安全余量的 API Key 调用 `K260824000104` | `routingAuthenticated`、`refreshing`、`offlineRetryable`、`routingAnonymous` |
| `refreshing` | 使用 Refresh Token 调用 `K260824000103` 并轮换整套凭据 | `validating`、`offlineRetryable`、`routingAnonymous` |
| `offlineRetryable` | 网络暂不可用，未把本地凭据当作已认证事实 | `initializing`、`validating`、`refreshing` |
| `routingAnonymous` | 清理无效状态并替换到手机号登录页 | 终态 |
| `routingAuthenticated` | 替换到安全深链或首页 | 终态 |
| `fatal` | 本机配置、加密或安全存储不可继续 | `initializing` |

`routing*` 为一次性导航状态。导航发出后，旧异步任务不得再次改变页面或安全存储。

## 2. 本地凭据判定

1. 整套凭据不存在：进入 `routingAnonymous`，不产生错误提示。
2. 只存在部分字段、无法解密或版本不支持：删除整套残留，记录不含字段值的安全事件，进入 `routingAnonymous`。
3. `refreshExpiresAt <= serverAdjustedNow`：删除整套凭据，进入 `routingAnonymous`。
4. `expiresAt - serverAdjustedNow > 10 分钟`：进入 `validating`。
5. 访问会话已过期或剩余不超过 10 分钟、Refresh Token 仍有效：进入 `refreshing`。

客户端时间仅用于提前触发；成功响应携带的服务端时间偏差由 session 层维护，页面不自行计算或修改时钟。

## 3. 服务端错误映射

| 来源 | 稳定结果 | 页面处理 |
|---|---|---|
| `K260824000103` | 成功 | 原子保存新凭据后进入 `validating` |
| `K260824000103` | `AUTH_REFRESH_CONCURRENT_UPDATE` | 只重新读取一次安全存储；若版本已提升则 `validating`，否则回登录 |
| `K260824000103` | `AUTH_REFRESH_REUSE_DETECTED` | 清除凭据、停止实时连接重连，回登录并显示通用安全说明 |
| `K260824000103` | Token 无效/到期/会话撤销 | 清除凭据并回登录 |
| `K260824000104` | 成功且账号/成员允许 | 写内存最小会话快照并导航 |
| `K260824000104` | `AUTH_SESSION_REVOKED` | 清除凭据并回登录；按稳定原因显示通用说明 |
| `K260824000104` | 账号冻结/归并 | 清除凭据，回登录或后续独立人工处理页；本页不展示内部详情 |
| 任一接口 | 明确离线、DNS、连接超时、503 | 保留可能有效的凭据，进入 `offlineRetryable` |
| 任一接口 | 响应解密/签名/契约失败 | 不信任响应；记录脱敏 requestId，进入 `fatal` |

HTTP 状态不是页面判断的唯一依据；错误必须先由 networking/application 层映射为稳定领域失败。

## 4. 深链决策

- 深链只能来自应用内受控解析结果，不直接使用原始 URL。
- 登录成功后再次经过登录守卫、路由白名单和参数校验。
- 未知路由、参数错误、越权目标或一次性链接过期时进入 `/home`。
- 未认证状态不持久化含敏感参数的深链；登录后恢复规则由 navigation 功能文档统一定义。

## 5. 不变量

- 本地存在凭据不等于 `authenticated`。
- 同一时刻最多一个启动恢复或刷新任务。
- 任何失败路径都不能留下半套新旧混合凭据。
- `offlineRetryable` 不开放受保护业务页面。
- 页面模型、错误对象、日志和埋点不携带凭据、手机号或统一账号。
