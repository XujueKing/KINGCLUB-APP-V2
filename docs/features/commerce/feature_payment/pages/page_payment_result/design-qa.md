# Design QA — Payment Formal Flow v3

- source visual truth：旧版 `pages/pay/pay.wxml`、`pay.wxss`，以及本页已批准的 Legacy Payment Result v2 文档。
- implementation screenshots：`audit/2026-08-29-formal-v3/01-ready.png`、`02-success.png`
- viewport：Xiaomi 14 Pro，1080 × 2400 px。
- state：KINGBAR 湖南工大店 / 888号桌 / 应付 3680 / 微信支付 / 服务器确认成功。

## Comparison evidence

- 结果页继续使用旧版居中图标、主文案、说明、底部主按钮和城市落款结构。
- 准备态沿用已批准的黑金径向画布、权威金额卡、支付方式卡和固定胶囊主按钮。
- 点单提交已通过替换式导航进入支付页，门店、桌号、商品与金额和上一步一致。
- 正常用户路径已移除 Fake、Mock、PaymentIntent、PaymentAttempt、provider、内部引用和测试说明。

## Findings

- 未发现可操作的 P0/P1/P2；固定底部按钮、系统导航区和正文卡片无裁切或遮挡。
- 支付只运行本地 UI Mock；真实超级接口和支付 SDK 继续受全局门禁阻断。
- 支付与确认专项测试加 App smoke 共 57 项通过，相关 Dart 静态检查无问题。

final result: passed
