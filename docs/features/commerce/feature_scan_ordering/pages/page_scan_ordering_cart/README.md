# 扫码点单商品/购物车页

- Scope ID：`KC-P-034`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[扫码点单](../../README.md)
- 旧版来源：`shoping`
- 路由：`ScanOrderingCartRoute`，`/commerce/ordering`，`$extra: OrderingContextRef`
- 设计版本：`Legacy Shoping Replica v2 / Cart`
- 最后更新：2026-08-27

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

## 旧版复刻基线

**已确认事实**

- 视觉与信息架构以旧版 `pages/shoping/shoping` 为主，保留黑色背景、黑金门店头部、顶部搜索、横向大类、左侧小类、右侧商品列表和底部购物袋。
- 购物袋展开后保留旧版的棕金头部、深色行项、清空入口与固定结算栏。
- App 不复制小程序右上角宿主胶囊，但不改动旧版点单主体层级。

**UI Mock 安全偏差**

- 底部金额标记为“预估”，“去确认”只产生 Fake Quote，不调用真实超级接口或支付 SDK。
- 门店与桌位使用已验证的 Fake `OrderingContextRef`，路由不携带原始二维码或可信桌位 ID。
- 商品图为本地 Mock 素材，用于完成旧版结构的真实视觉验收；实际商品与价格将在接口阶段由服务端目录提供。
