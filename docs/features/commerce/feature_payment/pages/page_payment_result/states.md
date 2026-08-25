# 支付处理与结果页状态

| 状态 | UI/动作 |
|---|---|
| `loadingIntent` | 安全骨架，无支付按钮 |
| `ready` | 权威金额与可用方式 |
| `creatingAttempt` | 禁重复 |
| `handingOff` | 外部支付交接说明 |
| `verifying` | 服务端确认中 |
| `succeeded` | 已确认成功、查看订单 |
| `cancelled` | 本次 attempt 取消，订单可待支付 |
| `failed` | 失败原因类别与允许动作 |
| `pending/unknown` | 不重复支付，查看订单/继续查询 |
| `expired/orderStateChanged` | 禁止旧意图，重读订单 |
| `offline/sessionInvalid` | 安全恢复或登录 reset |

未知 provider 状态不得映射成成功。
