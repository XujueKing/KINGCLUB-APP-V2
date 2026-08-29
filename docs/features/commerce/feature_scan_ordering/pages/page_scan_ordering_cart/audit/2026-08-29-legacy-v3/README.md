# KC-P-034 旧版点单复刻 v3 真机验收

- 日期：2026-08-29
- 设备：Xiaomi 14 Pro（`e1c31301`）
- 分辨率：1080 × 2400（系统物理屏 1440 × 3200，测试覆盖尺寸 1080 × 2400）
- 构建：Flutter preview debug / UI Mock
- 入口：`/commerce/ordering`

## 证据

- [01-catalog.png](01-catalog.png)：首次复刻首屏
- [02-added.png](02-added.png)：加购动作后目录
- [03-bag.png](03-bag.png)：购物袋展开态
- [04-catalog-final.png](04-catalog-final.png)：缩小标志并收拢分类后的最终首屏
- [05-confirm-handoff.png](05-confirm-handoff.png)：去结算进入确认页
- [06-return.png](06-return.png)：系统返回后草稿保留
- [12-vector-menu-pass1.png](12-vector-menu-pass1.png)：v3.1 使用 `.F_888` 真实矢量并按旧版 32/28/36/24 rpx 重排商品信息后的实机首屏

## 结论

- 门店头部、888、地址、一级分类、左侧酒类栏、旧版透明瓶图、数量控件和 3710 结算栏已按用户参考图复刻。
- 正常首屏没有 Fake、Mock、测试说明、桌位验证胶囊或额外订单按钮。
- 真实商品、价格、报价、支付和库存接口仍未接入；本轮只验证 UI Mock 与返回/交接路径。
- 专项测试 5/5、全量 Flutter 测试 257/257 通过，静态分析无问题。
- v3.1 的桌号不再是系统字体：`table_888.svg` 直接来自旧版 `.F_888` path，并恢复原 `tablestyle` 米金径向渐变。
- v3.1 商品信息列恢复旧版 `space-between`：名称/英文/规格贴顶，价格/数量贴底，XO、Chivas 和 VSOP 的基线与用户局部原图一致。

结果：通过。
