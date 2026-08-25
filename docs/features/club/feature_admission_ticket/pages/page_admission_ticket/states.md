# 入场凭证页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 状态/场次/码区骨架，无二维码 |
| `notYetAvailable` | 开放时间与规则，只读 |
| `issuingToken` | 码区进度，禁止展示旧永久码 |
| `readyToEnter` | 动态码、低频倒计时、帮助入口 |
| `refreshingToken` | 保留未过期码并显示刷新状态 |
| `tokenExpired` | 立即遮盖，重试/协助 |
| `checkedIn` | 入场时间与离场说明，无入场码 |
| `exitConfirmation` | 已验证 ScanContextRef，明确二次确认 |
| `exitSubmitting` | 防重复提交 |
| `exitResultUnknown` | 用原幂等键对账 |
| `checkedOutReentryAllowed` | 显示再次入场入口，重新签发时生成新码 |
| `checkedOutEnded/ended` | 只读记录 |
| `revoked/suspended` | 无码，订单/协助出口 |
| `offline` | 无有效码则只显示协助；不延长 token |
| `privacyCovered` | 后台、投屏或会话切换遮盖全部敏感区域 |
| `invalidRef/sessionInvalid` | 清理 token/引用并安全返回/reset |

未知状态只读；本地倒计时不得自行把凭证切成 checkedIn/checkedOut。
