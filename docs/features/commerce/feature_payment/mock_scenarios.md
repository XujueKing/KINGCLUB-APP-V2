# 支付 Mock 场景

| ID | 场景 | 预期 |
|---|---|---|
| PAY-M01 | 正常加载意图 | 权威金额和方式 |
| PAY-M02 | 意图过期 | 禁止支付，返回订单 |
| PAY-M03 | 订单已支付 | 查询后直接成功 |
| PAY-M04 | 订单已取消/不可支付 | 只读状态 |
| PAY-M05 | 创建 attempt 成功 | 单次拉起 Fake provider |
| PAY-M06 | 快速双击 | 只创建一次 |
| PAY-M07 | Fake SDK success + 服务端成功 | 显示成功 |
| PAY-M08 | Fake SDK success + 服务端 pending | 显示确认中 |
| PAY-M09 | Fake SDK cancel | 保留待支付订单 |
| PAY-M10 | Fake SDK fail | 失败说明与安全重试 |
| PAY-M11 | SDK 无回调 | 恢复查询 |
| PAY-M12 | App 切后台再回来 | reconcile |
| PAY-M13 | App 冷启动恢复 | 由订单/attempt 恢复 |
| PAY-M14 | 网络中断 | 不重复扣款 |
| PAY-M15 | 晚到成功 | 重读后显示成功 |
| PAY-M16 | provider 与服务端冲突 | 以服务端为准并支持 |
| PAY-M17 | 会话失效 | 清引用并登录 reset |
| PAY-M18 | 余额/金币方式不可用 | 服务端方式列表更新 |
| PAY-M19 | 0 元订单 | 不拉 SDK，查询订单确认 |
| PAY-M20 | 超时结果未知 | 去订单详情继续查询 |

全部由 Fake PaymentPort/Fake Provider 演示，不接真实 SDK。
