# 支付处理与结果页

- Scope ID：`KC-P-038`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[支付处理与结果](../../README.md)
- 旧版来源：`pay`
- 路由：`PaymentResultRoute`，`/commerce/payment`，`$extra: PaymentIntentRef | PaymentAttemptRef`
- 设计版本：`Legacy Payment Result v2 / Fake Orchestration`
- 最后更新：2026-08-27

## 旧版视觉基线

- 顶部使用旧 `pay` 的居中标题和 App 自有返回方式，不复刻微信胶囊。
- 支付结果继续使用旧 `success`/`pay` 的居中图标、主文案、说明和底部主按钮结构，并复用旧版真实 `success2.png` 与 `WEIPAY.png` 素材。
- 付款准备态延续当前 V2 订单详情的黑色径向画布、香槟金标题和浅棕金权威金额卡片。
- `SHANGHAI · ZHUZHOU` 作为旧版结果页落款保留；结果未知、失败和处理中使用同一结构而非新造视觉体系。

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

## 本轮 UI Mock 范围

- 默认演示权威金额 `¥1156`、微信支付 Fake 方式以及单次创建 Fake `PaymentAttemptRef`。
- Fake provider 的 success、cancel、fail、无回调都无条件进入服务端确认；只有 Fake 服务端返回 `succeeded` 才显示“支付已确认”。
- 长按标题可以切换 provider 成功但服务端待确认、失败、取消、无回调、晚到成功、意图过期、订单状态变化、离线、会话失效和 0 元订单。
- 0 元订单不展示支付方式、不创建 attempt、不拉起 provider，仅查询 Fake 订单确认结果。
- 页面只接收 `PaymentIntentRef` 或 `PaymentAttemptRef`；不从路由读取订单金额、用户、支付参数或成功标记。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
