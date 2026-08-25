# 支付处理与结果页交互

| 触发 | 行为 |
|---|---|
| 页面进入 | loadIntent 或 reconcile attempt |
| 选支付方式 | 仅选择 methodId，不手填金额 |
| 点确认支付 | 幂等创建 attempt，单次 handoff |
| provider 返回 | 无条件进入 verifying |
| 切后台/冷启动恢复 | reconcile 原 attempt |
| 点重试 | 先确认原 attempt 已明确失败且服务端允许 |
| 点稍后支付 | 返回订单详情，不取消业务订单 |
| 点查看订单 | replace 到 OrderDetailRoute |
| 会话失效 | 清引用并登录 reset |

返回键在 handingOff/verifying 时需说明仍在确认；不能诱导重复付款。
