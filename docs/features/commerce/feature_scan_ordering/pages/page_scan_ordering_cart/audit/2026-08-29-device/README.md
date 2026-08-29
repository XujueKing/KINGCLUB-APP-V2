# KC-P-034 Android 真机验收

- 日期：2026-08-29
- 设备：Xiaomi 14 Pro（`23116PN5BC`，arm64-v8a）
- 分辨率：1080 × 2400
- 构建：Flutter preview debug，Fake/Mock 数据
- 入口：`ScanOrderingCartRoute` / `/commerce/ordering`

## 验收路径

1. 查看门店、已验证桌位、三级类目和商品目录。
2. 加购星光香槟，核对数量、预估金额和确认按钮。
3. 展开购物袋，核对商品行、加减和合计。
4. 点击清空并检查二次确认；取消后保留商品。
5. 点击去确认，验证报价加载和 KC-P-035 路由交接。

## 证据

- [01-catalog.png](01-catalog.png)
- [02-cart-summary.png](02-cart-summary.png)
- [03-cart-sheet.png](03-cart-sheet.png)
- [04-clear-confirm.png](04-clear-confirm.png)
- [05-confirm-handoff.png](05-confirm-handoff.png)

## 发现与修复

- 初次验收发现清空确认正文直接显示 “Fake 草稿”，会让测试术语侵入正式用户界面。
- 已改为“只会清理当前门店和桌位的已选商品”，并同步清理无回调报价结果和隐藏验收场景标题中的 `Fake` 字样。
- 专项组件测试 5/5 通过，相关 Dart 静态检查无问题。

结果：旧版点单主体结构、加购、购物袋、清空确认和确认页交接通过 Android 真机验收。

说明：旧版 `shoping` 只有 WXML/WXSS 源码，没有同状态运行截图，因此本轮确认结构、视觉语言和交互范围，不声明逐像素一致。
