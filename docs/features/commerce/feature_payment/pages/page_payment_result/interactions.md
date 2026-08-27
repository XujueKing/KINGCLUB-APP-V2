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

## Fake 演示约定

- “确认支付”第一次点击立即锁定，快速双击不能创建第二个 Fake attempt。
- 交接和验证阶段返回时弹出说明；选择返回订单只结束页面展示，不取消业务订单或原 attempt。
- provider success 仅改变页面为“服务端确认中”；之后由 Fake reconcile 决定成功或待确认。
- provider cancel 显示“本次支付已取消，订单仍待支付”；不自动取消订单。
- 明确失败时“安全重试”先回到新的 Fake 意图准备态；pending/unknown 只允许查询原 attempt 或查看订单。
- 离线状态保留只读订单摘要，不创建 attempt；恢复网络后重新加载意图。
- 标题长按场景入口仅供 UI Mock 演示，不进入生产信息架构。
