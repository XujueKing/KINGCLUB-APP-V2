# 扫码点单商品/购物车页

- Scope ID：`KC-P-034`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[扫码点单](../../README.md)
- 旧版来源：`shoping`
- 路由：`ScanOrderingCartRoute`，`/commerce/ordering`，`$extra: OrderingContextRef`
- 设计版本：`Scan Ordering Wireframe v1 / Cart`
- 最后更新：2026-08-25

## 用户任务与线框

确认当前门店/桌位，浏览商品并编辑购物车。

```text
[返回]  门店名 · A08桌                    [订单]
[桌位已验证 · 本场次有效]
[分类栏]  酒水  小食  套餐
[商品图] 名称/规格/服务端展示价    [- 1 +]
...
[购物车 3件]   预估 ¥268              [去确认]
```

- “预估”必须明确；不展示客户端声称的优惠后最终价。
- 商品不可售、限购和目录更新必须在原位置说明。
- 200% 字体下底部操作条不遮挡商品和错误信息。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
