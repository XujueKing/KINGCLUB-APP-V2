# 订单详情与提交订单排版统一 v6

## 对照来源

- 用户于 2026-08-29 提供的“订单详情”和“提交订单”截图。
- 已验收提交订单实现截图：`../../../../feature_scan_ordering/pages/page_scan_order_confirmation/audit/2026-08-29-legacy-v3.1/01-confirm-alignment.png`。

## 真机结果

- 实现截图：`01-paid-scan-order.png`。
- 设备：Android `1080 × 2400`。
- 状态：扫码点单已支付，888号桌，轩尼诗 XO + 芝华士12年。

## 对照结论

- 顶部标题已统一为 16dp 常规字重和 52dp 顶栏。
- 浅棕信息卡使用 14dp 左右双列排版，右侧值统一右对齐。
- 商品卡完整复用提交订单的 44×70 图片、15dp 名称、11dp 规格/单价、17dp 小计及对应间距。
- 金额卡复用 13dp 普通行、16/22dp 强调行及相同行距。
- 已支付状态和原订单内容未改变，真机无溢出或遮挡。

## 自动验证

- `flutter analyze`：通过，0 issue。
- `flutter test test/order_detail_flow_test.dart test/payment_result_flow_test.dart`：通过，27 tests。

final result: passed
