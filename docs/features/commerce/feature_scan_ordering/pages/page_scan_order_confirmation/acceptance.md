# 点单确认页验收

- [x] 桌位、商品、优惠、费用和应付金额层级明确
- [x] 过期、变价、售罄、离线、会话失效状态明确
- [x] 变价重新确认和返回修改路径明确
- [x] 创建幂等、结果未知对账和成功出口明确
- [x] 页面不处理客户端资产分摊或支付成功判定
- [x] 用户于 2026-08-25 批准 `Scan Ordering Wireframe v1 / Confirmation`
- [x] 2026-08-27 按旧版 `shoping2` 补充复刻基线，延续“先复刻、后优化”的已批准方向
- [x] 旧版金币/余额/优惠券手填分摊不进入 V2 确认页，主操作固定为“提交订单”

UI Mock 阶段验证 ORDERING-M11～M20；全局文档门禁已满足，可以实现页面 Fake 流程。

## 2026-08-27 UI Mock 实现验收

- [x] Android 默认确认页：[screenshots/android_order_confirmation_v2.png](screenshots/android_order_confirmation_v2.png)
- [x] Android 价格/支付说明区：[screenshots/android_order_confirmation_details_v2.png](screenshots/android_order_confirmation_details_v2.png)
- [x] Android Fake 待支付订单结果：[screenshots/android_order_created_fake_v2.png](screenshots/android_order_created_fake_v2.png)
- [x] 变价确认、报价过期、售罄/限购、离线、会话失效和结果未知对账均已纳入 Fake 状态
- [x] `flutter analyze` 无问题，全量 `flutter test` 80 项通过
- [ ] 待获得旧版 `shoping2` 同状态运行截图后，完成同尺寸并排像素比对
