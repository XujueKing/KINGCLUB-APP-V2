# 商品/购物车页验收

- [x] 门店/桌位、分类、商品、购物车与预估金额层级明确
- [x] 空、加载、售罄、限购、离线、无效上下文状态明确
- [x] 草稿隔离、规格与数量交互、清空确认明确
- [x] 只经服务端报价进入确认页
- [x] 无障碍、隐私和埋点边界明确
- [x] 用户于 2026-08-25 批准 `Scan Ordering Wireframe v1 / Cart`
- [x] 2026-08-27 按旧版 `shoping` 完成复刻规则补充，延续“先复刻、后优化”的已批准方向
- [x] 顶部搜索、门店/桌位、横向大类、左侧小类、商品图文和购物袋展开态均纳入 UI 验收

UI Mock 阶段验证 ORDERING-M01～M12、M19～M20；全局文档门禁已满足，可以实现页面 Fake 流程。

## 2026-08-27 UI Mock 实现验收

- [x] Android 默认目录截图：[screenshots/android_scan_ordering_cart_v2.png](screenshots/android_scan_ordering_cart_v2.png)
- [x] Android 已选购物袋截图：[screenshots/android_scan_ordering_bag_v2.png](screenshots/android_scan_ordering_bag_v2.png)
- [x] 商品加减、搜索、预估金额、售罄、清空确认和 Fake Quote 已通过组件测试
- [x] `flutter analyze` 无问题，全量 `flutter test` 75 项通过
- [ ] 待获得旧版 `shoping` 同状态运行截图后，完成同尺寸并排像素比对
