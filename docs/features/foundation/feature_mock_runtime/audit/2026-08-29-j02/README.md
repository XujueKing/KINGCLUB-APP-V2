# J02 AA 预订、支付与订单详情验收

- 日期：2026-08-29
- 设备：Android 1080×2400 USB 真机
- 构建：Flutter `preview` Debug，初始路由 `/home`
- 数据：本地 UI Mock，未连接真实库存、价格、订单、支付或会员服务

## 通过链路

`首页 → 一起玩 AA → V5/3880 卡座套餐 → ¥268 确认订单 → 支付成功 → 同一 AA 订单详情`

## 证据

1. [首页入口](01-home.png)
2. [AA 日期与套餐列表](02-aa-list.png)
3. [V5/3880 套餐详情](03-package-detail.png)
4. [¥268 确认订单](04-order-confirmation.png)
5. [支付确认](05-payment.png)
6. [支付成功](06-payment-success.png)
7. [同一订单详情](07-order-detail.png)

## 一致性校验

- 全链路保持 `V5 卡座 / 3880卡座套餐 / ¥268 / 本人 1 席`，未串入 888 桌点单或其他 AA 样例。
- 支付成功后订单为“已确认”，不回退为“待支付”。
- `aa_reservation_flow_test.dart` + `payment_result_flow_test.dart` + `order_detail_flow_test.dart` 共 41 项通过，覆盖库存变化、重复预订、报价过期、支付未知、离线与会话失效。

final result: passed
