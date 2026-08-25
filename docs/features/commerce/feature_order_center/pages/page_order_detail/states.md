# 订单详情页状态

| 状态 | UI/动作 |
|---|---|
| `loading` | 详情骨架 |
| `content` | 权威状态、金额、时间线、动作 |
| `actionConfirming` | 取消等二次确认 |
| `actionSubmitting` | 禁止重复 |
| `actionResultUnknown` | 原幂等键对账 |
| `stateConflict` | 重读并提示最新状态 |
| `invalidRef/notFound/forbidden` | 统一安全错误，不泄漏归属 |
| `offlineCached` | 只读、标记缓存时间 |
| `unknownState` | 只读+刷新/支持 |
| `sessionInvalid` | 登录 reset |
