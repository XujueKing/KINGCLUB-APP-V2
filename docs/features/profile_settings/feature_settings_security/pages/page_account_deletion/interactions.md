# 账号注销页交互

| 触发 | 行为 |
|---|---|
| 页面进入/恢复 | 权威 preflight |
| 点 blocker | 只传受控引用去订单/钱包/储物等 |
| 点继续 | 短信重新认证，不复用登录旧 challenge |
| 最终确认 | expectedVersion + 幂等键提交 |
| 提交超时 | 原键 reconcile |
| 成功 | 撤销 KingClub 会话/Socket/push，清本地并 reset |

页面不得承诺删除物业共享身份或依法必须保留的数据。
