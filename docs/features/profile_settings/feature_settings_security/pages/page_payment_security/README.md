# 支付安全页

- Scope ID：`KC-P-044`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[设置与账号安全](../../README.md)
- 旧版来源：`modiffypwd`
- 路由：`PaymentSecurityRoute`，`/me/settings/payment-security`
- 设计版本：`Settings Wireframe v1 / Payment PIN`
- 最后更新：2026-08-25

## 线框

```text
[返回]              支付安全
状态：未设置 / 已设置 / 已锁定
[设置支付 PIN / 修改支付 PIN]
[忘记 PIN，短信验证后重设]

步骤：验证旧 PIN或短信 -> 输入新6位PIN -> 再次输入 -> 结果
```

使用安全数字输入组件，不显示手机号、旧凭据或尝试技术详情。状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
