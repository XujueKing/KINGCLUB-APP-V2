# 支付状态机

```text
loadingIntent -> ready -> creatingAttempt -> handingOff
             -> verifying -> succeeded
                          -> failed
                          -> cancelled
                          -> pending/unknown
```

## 权威规则

- `ready`：PaymentIntent 有效且订单仍允许支付。
- `handingOff`：已创建唯一 PaymentAttempt；禁用重复发起。
- `verifying`：不论 SDK 回调为何都查询服务端。
- `succeeded`：只能由服务端支付状态确认。
- `cancelled`：表示用户/SDK 取消本次 attempt，业务订单通常仍待支付。
- `pending/unknown`：轮询受控退避，可退出到订单详情；不创建新 attempt。
- `expired/orderStateChanged`：重读订单 allowedActions，禁止继续支付旧意图。

支付事件和 App 深链只触发 reconcile，不直接跃迁到 succeeded。
