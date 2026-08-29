# 稳定单聊

- Scope ID：`KC-F-021`
- 文档状态：`Approved for Development`
- 所属业务域：`messaging`
- M0 范围：`In Release Scope`
- 设计版本：`Direct Chat v1`
- 最后更新：2026-08-25

## 目标与用户价值

为已经建立好友关系的两位会员提供可补偿、可重试、不会重复发送的文本和媒体单聊，并支持必要的会话设置与单人转发。

## 已确认事实

- 旧 `chat` 先用时间戳插入本地消息，再经 HTTP/推送发送并另外发裸 WebSocket 提示，失败状态和幂等边界不完整。
- 旧媒体上传 URL 拼接账号和会话 ID，使用共享 Authorization；删除/撤回多为本地修改。
- 旧聊天混入群申请、红包、金币、礼物、充值和支付；其中群申请、充值和真实交易继续不属于本期稳定单聊，红包、金币与礼物于 2026-08-29 仅恢复 UI/Mock 演示。
- 旧 `chat_more` 同时承担单聊和完整群管理；后者已暂缓。

## 当前建议

- M0 消息类型：文本/emoji、图片、短视频、引用、转发副本、批准的业务卡片、系统提示、撤回占位，以及本地 Fake 金币/红包/礼物卡片。
- 不包含语音、文件、位置、收藏、群消息、批量转发及任何真实资产交易。
- HTTP/API 持久化结果是权威；WebSocket 只做实时事件。发送使用稳定 `clientMessageId`，失败重试复用同一 ID。
- 消息状态：`queued | uploading | sending | sent | delivered | read | failed | revoked`；服务端不支持的送达/已读能力不得伪造。
- 只有 friendship 状态可发送；删除好友或拉黑后历史只读，输入区禁用。
- 联系人选择只允许单个好友/单聊目标，不支持多选群发。

## 页面与文档

- [KC-P-024 单聊页](pages/page_direct_chat/README.md) — `Approved for Development`
- [KC-P-025 单聊详情页](pages/page_direct_chat_details/README.md) — `Approved for Development`
- [KC-P-026 联系人选择页](pages/page_contact_selector/README.md) — `Approved for Development`
- [旧版审计](legacy_audit.md)
- [消息状态机与导航](flow_and_navigation.md)
- [数据与 Fake 契约](data_and_api.md)
- [隐私与安全](privacy_and_safety.md)
- [Mock 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 已确认决策

1. 首发消息类型按上述集合；语音、文件、收藏和批量转发暂缓，红包、金币和礼物仅恢复 UI/Mock，真实接入继续暂缓。
2. 只允许好友发消息；关系结束后保留只读历史但禁用发送。
3. 单聊详情包含免打扰、置顶、聊天记录搜索、关系权限和“为我清空记录”；不做聊天背景。
4. 联系人选择一次只选择一个好友，转发/业务卡片发送前必须二次确认。
5. 旧版聊天扩展由 [KC-F-033 聊天扩展面板与礼物 Mock](../feature_chat_extensions/README.md)约束，不增加页面路由。

## 开发门禁

本功能已达到文档准入；全部 48 页批准前不创建 Flutter UI，全局 UI Flow Approved 前不接真实消息、媒体、WebSocket、推送或业务分享接口。
