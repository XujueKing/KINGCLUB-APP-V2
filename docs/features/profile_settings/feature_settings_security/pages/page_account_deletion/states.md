# 账号注销页状态

| 状态 | UI/动作 |
|---|---|
| `loadingPreflight` | 不可提交 |
| `blocked` | blocker 与处理入口 |
| `eligible` | 影响/留存摘要与继续 |
| `reauthenticating` | 短信 challenge |
| `finalConfirming/submitting` | 明确永久动作、禁重复 |
| `resultUnknown` | 对账，不声称成功 |
| `completed` | 清理并 reset |
| `stateChanged/sessionInvalid` | 重做 preflight 或安全 reset |
