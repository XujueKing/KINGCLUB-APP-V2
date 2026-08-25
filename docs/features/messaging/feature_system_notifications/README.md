# 系统通知

- Scope ID：`KC-F-020`
- 文档状态：`Approved for Development`
- 所属业务域：`messaging`
- M0 范围：`In Release Scope`
- 设计版本：`System Notifications v1`
- 最后更新：2026-08-25

## 目标与用户价值

集中查看账号、会员、预约入场、订单支付、资产和平台通知，同时清楚区分“通知摘要”与业务最终事实。

## 已确认事实

- 旧 `sysmessage` 用类型码和自由内容数组直接渲染金额、订单和金币卡片，点击详情没有实现。
- 旧页面用页码追加，未定义去重、已读、动作权限和断线补偿。
- 新 WebSocket 已有通知、ACK 与未读查询底座，但通知不能作为订单/支付最终状态。

## 当前建议

- 通知类别固定为 `accountSecurity | membership | reservationAdmission | orderPayment | asset | platform`。
- 卡片展示清洗后的标题、摘要、时间和状态标签；可展开有限详情，不渲染任意富文本/HTML。
- 点击卡片或展开后标记已读；提供“全部已读”，不提供客户端删除通知。
- 动作使用受控 `NotificationAction`，目标页重新读取权威业务对象；未批准/不可用目标保持只读。
- 推送锁屏文案默认隐私化，不含金额、订单号、手机号、实名或消息正文。

## 页面与文档

- [KC-P-023 系统通知页](pages/page_system_notifications/README.md) — `Approved for Development`
- [旧版审计](legacy_audit.md)
- [流程与导航](flow_and_navigation.md)
- [数据与 Fake 契约](data_and_api.md)
- [Mock 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 已确认决策

1. 系统通知使用六个固定类别，不把好友申请混入这里。
2. 阅读后可标记已读/全部已读，但本期不删除通知。
3. 通知只作摘要，进入订单、资产、入场等页面后必须重新读取权威状态。

## 开发门禁

本功能已达到文档准入；全部 48 页批准前不创建 Flutter UI，全局 UI Flow Approved 前不接真实通知、推送或业务接口。
