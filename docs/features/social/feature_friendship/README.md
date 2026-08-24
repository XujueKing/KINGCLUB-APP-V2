# 好友申请与添加

- Scope ID：`KC-F-016`
- 文档状态：`In Review`
- 所属业务域：`social`
- M0 范围：`In Release Scope`
- 设计版本：`Friendship v1`
- 最后更新：2026-08-25

## 目标与用户价值

通过受控短期二维码发现用户，查看收到/发出的申请，并完成发送、接受或拒绝好友申请的可靠闭环。

## 已确认事实

- 旧 `addfriend` 同页生成含永久账号的二维码并直接调用相机解析 URL。
- 旧申请列表把申请 ID、对方账号、状态、留言和来源全部拼入详情 URI；处理接口用数字 typeId。
- Safe Scanner v1 已批准只解析受控二维码；个人二维码已批准使用 10 分钟 `friendInviteToken`。
- 统一用户主页承担申请详情状态，避免保留 `friendinfo/newfriendInfo/userInfo` 三套近似页面。

## 当前建议

- KC-P-015 是“添加好友入口页”，只提供“扫一扫”和“我的二维码”两个固定入口；相机由 KC-P-012、个人码由 KC-P-042 拥有。
- 好友申请列表同时显示收到和发出的记录，通过方向与状态标签区分，不额外增加 Tab。
- 接受/拒绝放在 KC-P-017 用户主页的申请上下文中；列表不执行破坏性快捷操作。
- 发送申请可填写验证消息和自己的私有备注；使用幂等键，重复发送或状态竞态以服务端权威结果收口。
- 不提供手机号、实名、永久账号搜索，也不根据二维码直接自动加好友。

## 页面与文档

- [KC-P-015 添加好友入口页](pages/page_add_friend/README.md) — `In Review`
- [KC-P-016 好友申请列表页](pages/page_friend_requests/README.md) — `In Review`
- [KC-P-018 发送好友申请页](pages/page_send_friend_request/README.md) — `In Review`
- [旧版审计](legacy_audit.md)
- [流程与状态机](flow_and_navigation.md)
- [数据与 Fake 契约](data_and_api.md)
- [Mock 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 本期不包含

- 附近的人、雷达、系统通讯录邀请、推荐算法、批量申请、关注/粉丝或群邀请。
- 二维码保存/分享、永久码、任意 URL 扫描和扫描后自动建立关系。
- 真实相机、二维码签发、好友接口或 WebSocket 通知接入。

## 待用户确认

1. 添加好友页只做“扫一扫/我的二维码”入口，不重复实现扫码器和二维码。
2. 申请列表合并收到与发出记录，不增加两个 Tab；处理动作进入统一用户主页完成。
3. 不支持手机号/账号搜索，扫码也必须先预览并明确发送申请。

## 开发门禁

用户批准后才可标记文档准入；全部 48 页批准前不创建 Flutter UI，全局 UI Flow Approved 前不连接真实接口、相机或 WebSocket。
