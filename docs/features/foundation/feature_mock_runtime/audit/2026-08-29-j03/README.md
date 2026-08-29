# J03 安全扫码、点单与支付验收

- 日期：2026-08-29
- 设备：Android 1080×2400 竖屏 + 2400×1080 横屏 USB 真机
- 数据：本地 UI Mock，未读取真实相机、二维码、商品、报价、订单或支付服务

## 通过链路

`首页 SCAN QR → 用途说明 → Fake 桌台码 → 受控桌台点单意图 → 888 桌购物车 → 提交订单 → ¥3680 支付 → 支付成功`

## 证据

1. [首页扫码入口](01-home.png)
2. [安全扫码用途说明](02-safe-scanner.png)
3. [888 桌点单购物车](03-ordering-cart.png)
4. [点单确认](04-order-confirmation.png)
5. [¥3680 支付准备态](05-payment.png)
6. [支付成功](06-payment-success.png)
7. [支付后订单交接](07-order-detail.png)
8. [横屏成功态溢出修复](08-payment-landscape-fixed.png)
9. [恢复竖屏后的回归](09-payment-portrait-regression.png)

## 审计发现与修复

- 首次真机横屏发现支付成功页底部 `RenderFlex overflow 32px`。
- 先回写支付页横屏恢复规则，再将居中结果容器改为保持最小高度的纵向可滚动结构。
- 修复后黄黑溢出条消失，“查看订单”和 `SHANGHAI · ZHUZHOU` 均可到达；恢复竖屏后居中视觉无回归。
- 扫码、购物车与点单确认 25/25 项通过，支付专项 13/13 项通过，覆盖无效/过期/离线扫码、售罄、价格变化、重复提交和横屏。
- 新增 `2400×1080 @3x` 支付成功态横屏回归；`flutter analyze` 0 问题。

final result: passed
