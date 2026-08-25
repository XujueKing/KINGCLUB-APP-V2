# 钱包与资产流水页

- Scope ID：`KC-P-039`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[钱包与资产流水](../../README.md)
- 旧版来源：`mybalance`
- 路由：`AssetLedgerRoute`，`/me/assets`
- 设计版本：`Asset Ledger Wireframe v1`
- 最后更新：2026-08-25

## 用户任务与线框

查看本人各类资产摘要，按资产和月份浏览权威流水。

```text
[返回]            钱包与资产
[余额 ¥120.00] [金币 280] [钻石 16]
 可用/冻结/处理中 · 更新于 21:03
[余额] [金币] [钻石]             [2026-08]
本月收入/支出（服务端摘要）
订单消费                         -¥68.00
8月25日 20:31 · 已入账             [订单]
退款处理中                       +¥20.00
8月24日 18:10 · 处理中
```

- 不显示跨资产“总资产”，不同单位不使用同一金额格式。
- 正负号必须同时配合“收入/支出/处理中/冲正”文本，不只依赖颜色。
- 页面没有充值、提现、兑换和转赠按钮。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
