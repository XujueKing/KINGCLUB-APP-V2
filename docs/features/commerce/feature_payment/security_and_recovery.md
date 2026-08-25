# 支付安全与恢复

- PaymentIntentRef、PaymentAttemptRef 均不透明、短时、绑定当前账户与订单。
- provider 参数只从受信任 adapter 接收，不写日志、不持久化完整 payload。
- 创建 attempt 使用幂等键；恢复时优先查询原 attempt，禁止“没看到结果就再付一次”。
- 前后台切换、冷启动和回跳丢失统一进入 verifying。
- 会话切换清除引用和支付展示缓存；订单详情重新获取新 PaymentIntent。
- 截图/埋点不得包含 provider 凭据、签名、完整订单号、手机号或实名信息。
- 客户端不验证支付签名作为最终业务结论；签名与回调验真属于服务端支付适配域。
