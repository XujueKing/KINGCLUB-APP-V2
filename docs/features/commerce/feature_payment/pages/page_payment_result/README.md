# 支付处理与结果页

- Scope ID：`KC-P-038`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[支付处理与结果](../../README.md)
- 旧版来源：`pay`
- 路由：`PaymentResultRoute`，`/commerce/payment`，`$extra: PaymentIntentRef | PaymentAttemptRef`
- 设计版本：`Payment Wireframe v1`
- 最后更新：2026-08-25

## 用户任务与线框

```text
[关闭]              支付
订单摘要
应付金额                         ¥268.00
[支付方式（服务端可用列表）]
                                  [确认支付]

结果变体：
[处理中] 正在向服务端确认，请勿重复支付
[成功]   支付已确认              [查看订单]
[取消]   本次支付已取消          [稍后支付]
[失败]   未完成扣款              [重试]
[待确认] 暂无法确认结果          [查看订单]
```

成功状态必须带“服务端已确认”语义；不能仅依据绿色对勾、SDK 文案或路由参数。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
