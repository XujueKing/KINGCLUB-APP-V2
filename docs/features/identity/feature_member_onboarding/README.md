# 会员准入与资料初始化

- Scope ID：`KC-F-011`

- 文档状态：`Draft`
- 所属业务域：`identity`
- M0 范围：`In Release Scope`
- 最后更新：2026-08-24

## 目标与用户价值

完成实名成年核验、会员形象资料、兴趣偏好和审核状态闭环。

## 本期包含

- [KC-P-005 实名与成年核验页](pages/page_real_name_adult_verification/README.md) — `Draft`
- [KC-P-006 会员形象资料页](pages/page_membership_image_submission/README.md) — `Draft`
- [KC-P-007 着装与音乐偏好页](pages/page_style_music_preferences/README.md) — `Draft`
- [KC-P-008 酒类与活动偏好页](pages/page_drink_event_preferences/README.md) — `Draft`
- [KC-P-009 会员审核状态页](pages/page_membership_review_status/README.md) — `Draft`

## 本期不包含

手机号登录与会话由 feature_login_session 负责。

## 待设计内容

- 用户角色、入口、前置条件、主流程和异常流程
- 业务规则、状态机、权限和跨页面导航
- UI 线框/设计版本、全部页面状态和 Mock 场景
- Repository/port、API 或临时 Mock 契约
- 隐私、安全、埋点、测试、灰度与回滚

## 开发门禁

本目录建立只表示进入文档设计队列。功能与所属页面全部达到 `Approved for Development` 前不得开发；本期 48 页全部文档批准前不得创建 Flutter UI，整 App 达到 `UI Flow Approved` 前不得连接真实服务。
