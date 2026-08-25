# AA 确认订单页

- Scope ID：`KC-P-029`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[一起玩 AA 预订](../../README.md)
- 旧版来源：`order2`
- 路由：`AaOrderConfirmationRoute`，`/club/aa/confirm`，`$extra: AaQuoteRef`
- 设计版本：`AA Reservation Wireframe v1 / Confirmation`
- 最后更新：2026-08-25

## 用户任务与线框

核对服务端最新报价、选择允许的抵扣、确认规则，并创建一张短时占位的待支付订单。

```text
[返回]              确认订单

[预订信息]
 8月25日 20:30—次日04:00
 卡座区域 / 套餐名 / 本人 1 席

[优惠与抵扣]
 活动优惠（服务端已应用）              -¥60.00
 优惠券                               [未选择 >]
 余额抵扣                             [未使用 >]
 金币抵扣（若政策允许）                [未使用 >]

[金额明细]
 套餐人均价                            ¥388.00
 优惠与抵扣                            -¥60.00
 待支付                                ¥328.00
 报价剩余 04:32

[ ] 我已阅读并同意本次预订、迟到和取消规则 [查看]

待支付 ¥328.00                    [确认并去支付]
```

- 每次抵扣变更都显示刷新状态，并用新的 `quoteRevision` 替换整份金额明细。
- 不允许手输余额/金币金额；采用服务端给出的可选方案或“最多可抵扣”选项，降低输入和舍入错误。
- 提交成功只表示获得 `pendingPayment` 或免付确认结果；不得在本页宣告第三方支付成功。
- 0 元订单按钮文案为“确认预订”，仍由服务端创建并确认订单，不能客户端直接成功。
- 规则勾选绑定 `termsSnapshotRef`；报价/规则更新后必须重新确认。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
