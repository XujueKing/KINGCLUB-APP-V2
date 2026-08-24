# 验证码页状态与错误映射

## 1. 页面状态

| 状态 | 含义 | 允许动作 |
|---|---|---|
| `editing` | challenge 有效，等待六位验证码 | 输入、返回、到期后重发 |
| `submitting` | K102 登录事务执行中 | 仅等待；禁止编辑、重发和重复提交 |
| `invalidCode` | 验证码错误但 challenge 尚可用 | 清空后重新输入 |
| `preflightRetryable` | 客户端能证明 K102 尚未离开设备 | 保留输入，用户明确重试；不自动发短信 |
| `outcomeUnknown` | K102 已发出但未取得可信结果 | 清除 PendingSmsLogin，重新获取验证码 |
| `identityRetryable` | 物业权威身份暂时不可用 | 保留流程，按错误策略重试登录 |
| `consentVersionChanged` | 登录使用的协议已不是当前版本 | 清空验证码与旧同意，刷新 K107 |
| `expired` | challenge 到期、失效或已消费 | 禁止提交，重新获取 |
| `locked` | 当前 challenge 达到错误上限 | 禁止提交，冷却后重新获取 |
| `resending` | K101 正在请求新 challenge | 保留当前 challenge，禁止重复重发 |
| `resendRateLimited` | K101 返回等待时间 | 显示服务端截止时间，当前 challenge 未过期时仍可输入 |
| `committingSession` | 登录成功，Session Repository 原子提交凭据 | 禁止离开和重复操作 |
| `success` | 凭据提交完成、会话复核可继续 | replace 到受控目标路由 |
| `manualReview` | 统一身份冲突或账号状态需人工处理 | 不签发/不保留会话，展示帮助入口 |

页面状态由登录流程协调器统一持有；Widget 不得自行复制 challenge、手机号、协议或会话状态。

## 2. 输入 revision 与 SingleFlight

- 手输、合法粘贴和系统验证码填充统一生成新的 `inputRevision`。
- 只有规范化后恰好六位、页面处于 `editing` 且该 revision 未提交时，才触发一次 K102。
- 同一 revision 的重建、焦点变化、动画和系统 autofill 回调不得产生第二次请求。
- `AUTH_CODE_INVALID` 后清空输入并递增 revision；不得自动重放错误验证码。
- 只有断网、握手失败等能证明 K102 业务请求未发出时，用户点击“重试验证”才复用当前流程上下文；每次传输仍使用新握手、requestId 和 nonce。
- K102 发出后的超时、断连或响应无法验真属于 `outcomeUnknown`，不得用新 requestId 重放同一验证码。

## 3. K102 错误映射

| 服务端结果 | 页面状态 | 页面规则 |
|---|---|---|
| 成功 | `committingSession` | 响应凭据只交给 Session Repository，不进入页面日志/状态快照 |
| `AUTH_CODE_INVALID` | `invalidCode` | 通用“验证码不正确，请重新输入”，不显示剩余次数 |
| `AUTH_CHALLENGE_EXPIRED` | `expired` | 清空验证码，允许重新获取 |
| `AUTH_CHALLENGE_INVALID` | `expired` | 不区分手机号/场景/挑战哪项不匹配 |
| `AUTH_CHALLENGE_LOCKED` | `locked` | 当前 challenge 停止使用，不尝试客户端绕过 |
| `AUTH_CONSENT_VERSION_INVALID` | `consentVersionChanged` | challenge 保持；清除旧同意和验证码，刷新 K107 |
| `IDENTITY_AUTHORITY_UNAVAILABLE` | `identityRetryable` | 不本地发号；展示可重试提示，不自动重发短信 |
| `IDENTITY_BINDING_CONFLICT` | `manualReview` | 不自动合并账号，显示通用人工处理入口 |
| `AUTH_ACCOUNT_DISABLED` | `manualReview` | 不签发会话，不透露更多账号资料 |
| `AUTH_MEMBERSHIP_RESTRICTED` | `manualReview` | 仅进入后续批准的受限说明/申诉流程 |
| 业务请求发出前握手/本地网络失败 | `preflightRetryable` | 可由用户重试，不自动无限重试 |
| K102 发出后超时、断连或响应无法验真 | `outcomeUnknown` | 不重放验证码；清空流程并重新获取，记录脱敏 requestId |

任何服务端内部码都必须由 Repository 映射为稳定领域错误，页面不显示堆栈、数据库、短信供应商或物业服务细节。

## 4. 双截止时间

- `challengeExpiresAt` 决定验证码是否还能提交，默认对应服务端 300 秒有效期。
- `resendAvailableAt` 决定何时可请求新短信，默认对应 60 秒冷却。
- 两者都从服务端相对秒数转换成本机单调时钟截止点；前后台恢复时按截止点重算，不逐秒持久化。
- 重发可用不代表旧 challenge 已过期；在新 challenge 明确成功前，旧 challenge 仍按其原截止时间工作。
- 系统时间跳变、页面 rebuild 或旋转不得延长任何服务端时效。

## 5. 凭据提交失败

K102 的一次性响应可能包含 `apiKey` 和 `refreshToken`。页面只把完整响应交给 Session Repository：先写入带 generation 的暂存 bundle，全部成功后切换活动指针；失败时删除暂存内容并保持匿名态。具体存储实现属于后续 `session/persistence` foundation，不允许 Widget 逐字段写入。

当前 K102 没有登录业务幂等键，也没有短期凭据响应重放仓。若服务端已提交但响应丢失，challenge 已消费且客户端无法恢复凭据。V1 采用失败关闭：`outcomeUnknown` 重新获取验证码；下一次成功登录利用单设备约束撤销可能遗留的活动会话。若未来要做到无感恢复，必须另行设计服务端敏感响应幂等仓、TTL、加密和清理规则，不能只在客户端自动重试。
