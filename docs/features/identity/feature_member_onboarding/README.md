# 会员注册、资料初始化与准入

- Scope ID：`KC-F-011`
- 文档状态：`In Review`
- 所属业务域：`identity`
- M0 范围：`In Release Scope`
- 设计版本：`Member Onboarding v1`
- 最后更新：2026-08-25

## 目标与用户价值

让已完成手机号登录但尚未取得 KingClub 会员资格的用户，以清晰、可恢复且保护隐私的流程完成实名成年核验、会员形象资料、兴趣偏好和审核状态闭环。

## 已确认事实

- 旧版顺序为 `regist2 → regist3 → regist4 → regist5 → success`。
- 旧版在客户端从身份证号计算年龄、把证件/人脸图片转 Base64，并通过旧接口提交手机号或 `userAccount`；这些做法不能复用。
- K101～K107 只完成登录、会话、协议和最小成员摘要，尚无 V2 会员准入业务接口。
- KYC 状态与 KingClub 会员审核状态是两个不同事实：实名通过不等于会员审核通过。
- 用户身份必须来自可信 Session，页面不得提交 `userAccount` 或手机号作为授权依据。

## 当前建议

```text
手机号登录成功
  -> K104/OnboardingSnapshot 复核
  -> KC-P-005 实名与成年核验
  -> KC-P-006 两张会员形象资料
  -> KC-P-007 着装/音乐偏好（可跳过）
  -> KC-P-008 酒类/活动偏好（可跳过并最终提交）
  -> KC-P-009 审核状态
      -> approved：reset App Shell 首页
      -> changesRequired：只回到服务端指定步骤
      -> rejected：按服务端策略重提或联系客服
```

- 成年结论只认服务端/已批准核验方，客户端仅做输入格式提示。
- 证件、人脸和照片不写普通本地存储、不进日志/埋点/URI；真实接入前必须确定核验供应商、上传链路、留存期和隐私文案。
- 会员图片按“清晰度、真实性、内容安全和已公布入会规范”审核，不在 UI 展示“颜值分”，不显示模型内部标签。
- 偏好使用稳定 optionId，不传中文逗号字符串；V1 允许跳过，不影响实名或会员审核。

## 页面

- [KC-P-005 实名与成年核验](pages/page_real_name_adult_verification/README.md) — `In Review`
- [KC-P-006 会员形象资料](pages/page_membership_image_submission/README.md) — `In Review`
- [KC-P-007 着装与音乐偏好](pages/page_style_music_preferences/README.md) — `In Review`
- [KC-P-008 酒类与活动偏好](pages/page_drink_event_preferences/README.md) — `In Review`
- [KC-P-009 会员审核状态](pages/page_membership_review_status/README.md) — `In Review`

## 配套文档

- [用户流程与导航](flow.md)
- [准入状态机](state_machine.md)
- [数据、Repository 与待建接口契约](data_and_api.md)
- [隐私、安全与审核公平性](privacy_and_safety.md)
- [Mock/Fake 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 本期不包含

- 登录、协议目录和会话签发；由 KC-F-010 负责。
- 完整人工审核后台、模型训练台或运营审核队列。
- App 内申诉页面；本期只显示批准的客服方式和可重提状态。
- 真实人脸 SDK、真实媒体上传、真实准入接口或审核 WebSocket 接入。

## 待用户确认

1. 继续要求两张会员形象资料：一张清晰正面照、一张近期半身/全身照。
2. 四类兴趣偏好均允许跳过，不作为会员审核硬门槛。
3. UI 不出现“颜值评分”及模型内部标签，改用公开、可解释的资料质量与入会规范。
4. 被拒绝后是否允许重提、冷却时间和客服渠道由服务端策略返回；本期不单建申诉页。
5. 实名/人脸核验供应商与正式隐私留存文案在真实接入前另行批准。

## 开发门禁

当前评审包只定义产品、UI 和 Fake/port 契约。用户批准后才可更新为 `Approved for Development`；仍须等待本期全部 48 页文档准入后才能创建 Flutter UI，项目达到 `UI Flow Approved` 前不得连接真实服务或身份 SDK。
