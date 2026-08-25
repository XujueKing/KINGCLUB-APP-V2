# KINGCLUB APP V2 Flutter 规划入口

更新时间：2026-08-24

## 目标

本目录定义 KingClub App V2 的 Flutter 总体架构、功能边界、实施顺序和文档先行规则。它是开发前的规划基线，不替代旧版审计与数据库迁移资料。

## 状态标签

所有关键结论必须使用以下标签之一：

- **已确认事实**：已从旧版源码、现有资料或用户指令确认。
- **当前建议**：当前阶段推荐采用，但可在评审后调整。
- **待用户决策**：会显著影响产品或技术方案，尚未获得确认。

## 必读顺序

1. [ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md)：Flutter V2 总体架构
2. [FEATURE_MAP.md](FEATURE_MAP.md)：业务域、功能与页面总览
3. [ROADMAP.md](ROADMAP.md)：分阶段建设路线
4. [DOCUMENTATION_FIRST_WORKFLOW.md](DOCUMENTATION_FIRST_WORKFLOW.md)：文档先行与开发准入规则
5. [../features/README.md](../features/README.md)：功能和页面文档目录规范
6. [BACKEND_FOUNDATION_PHASE.md](BACKEND_FOUNDATION_PHASE.md)：数据库、超级接口、登录鉴权与 WebSocket 第一阶段
7. [Flutter Foundation 功能目录](../features/foundation/README.md)：App 工程创建前的五个技术底座模块
8. [ADR-0001 Flutter Foundation 技术基线](adr/0001_flutter_foundation_baseline.md)：已批准的 SDK、平台与核心依赖基线
9. [App 范围、页面覆盖与 UI 交付门禁](APP_SCOPE_AND_UI_DELIVERY_GATE.md)：本期全量文档、UI Mock 与真实接入覆盖账本
10. [本期范围评审包](scope/README.md)：旧版 69 路由审计与已冻结的 48 页首发范围

首批页面评审入口：

1. [启动鉴权页](../features/identity/feature_login_session/pages/page_auth_bootstrap/README.md)
2. [手机号登录页](../features/identity/feature_login_session/pages/page_mobile_login/README.md)
3. [验证码页](../features/identity/feature_login_session/pages/page_sms_verification/README.md)
4. [协议确认页](../features/identity/feature_login_session/pages/page_terms_consent/README.md)

已批准的全局 UI 基线：

1. [App Shell 与信息架构](../features/foundation/feature_app_shell/README.md)
2. [KC-P-010 App Shell 页面线框](../features/foundation/feature_app_shell/pages/page_app_shell/README.md)
3. [路由与导航](../features/foundation/feature_navigation/README.md)
4. [Design System v1](../features/foundation/feature_design_system/README.md)

已批准的会员准入页面：

1. [Member Onboarding v1](../features/identity/feature_member_onboarding/README.md)
2. [实名与成年核验页](../features/identity/feature_member_onboarding/pages/page_real_name_adult_verification/README.md)
3. [会员形象资料页](../features/identity/feature_member_onboarding/pages/page_membership_image_submission/README.md)
4. [着装与音乐偏好页](../features/identity/feature_member_onboarding/pages/page_style_music_preferences/README.md)
5. [酒类与活动偏好页](../features/identity/feature_member_onboarding/pages/page_drink_event_preferences/README.md)
6. [会员审核状态页](../features/identity/feature_member_onboarding/pages/page_membership_review_status/README.md)

已批准的首页与扫码页面：

1. [Home Hub v1](../features/home/feature_home_hub/README.md)
2. [KC-P-011 首页](../features/home/feature_home_hub/pages/page_home/README.md)
3. [Safe Scanner v1](../features/home/feature_safe_scanner/README.md)
4. [KC-P-012 扫码识别与安全分流页](../features/home/feature_safe_scanner/pages/page_safe_scanner/README.md)

已批准的个人中心页面：

1. [Profile Center v1](../features/profile_settings/feature_profile_center/README.md)
2. [KC-P-040 我的主页](../features/profile_settings/feature_profile_center/pages/page_my_profile/README.md)
3. [KC-P-041 编辑个人资料页](../features/profile_settings/feature_profile_center/pages/page_edit_profile/README.md)
4. [KC-P-042 个人二维码页](../features/profile_settings/feature_profile_center/pages/page_personal_qr/README.md)

已批准的社交关系页面：

1. [KC-P-014 通讯录页](../features/social/feature_contacts/pages/page_contacts/README.md)
2. [KC-P-015 添加好友入口页](../features/social/feature_friendship/pages/page_add_friend/README.md)
3. [KC-P-016 好友申请列表页](../features/social/feature_friendship/pages/page_friend_requests/README.md)
4. [KC-P-017 用户主页](../features/social/feature_user_profile/pages/page_user_profile/README.md)
5. [KC-P-018 发送好友申请页](../features/social/feature_friendship/pages/page_send_friend_request/README.md)
6. [KC-P-019 好友备注页](../features/social/feature_relationship_controls/pages/page_friend_remark/README.md)
7. [KC-P-020 关系权限页](../features/social/feature_relationship_controls/pages/page_relationship_permissions/README.md)
8. [KC-P-021 黑名单页](../features/social/feature_relationship_controls/pages/page_blacklist/README.md)

已批准的消息页面与实时传输端口：

1. [KC-P-022 会话列表页](../features/messaging/feature_conversation_list/pages/page_conversations/README.md)
2. [KC-P-023 系统通知页](../features/messaging/feature_system_notifications/pages/page_system_notifications/README.md)
3. [KC-P-024 单聊页](../features/messaging/feature_direct_chat/pages/page_direct_chat/README.md)
4. [KC-P-025 单聊详情页](../features/messaging/feature_direct_chat/pages/page_direct_chat_details/README.md)
5. [KC-P-026 联系人选择页](../features/messaging/feature_direct_chat/pages/page_contact_selector/README.md)
6. [KC-F-022 WebSocket 实时传输基础](../features/messaging/feature_realtime_transport/README.md)

已批准的一起玩 AA 页面：

1. [KC-P-027 一起玩 AA 预订页](../features/club/feature_aa_reservation/pages/page_aa_reservations/README.md)
2. [KC-P-028 AA 卡座套餐详情页](../features/club/feature_aa_reservation/pages/page_aa_package_detail/README.md)
3. [KC-P-029 AA 确认订单页](../features/club/feature_aa_reservation/pages/page_aa_order_confirmation/README.md)
4. [KC-F-023 一起玩 AA 功能契约](../features/club/feature_aa_reservation/README.md)

已批准的 VIP 组局页面：

1. [KC-P-030 VIP 组局列表/详情页](../features/club/feature_vip_party/pages/page_vip_party_detail/README.md)
2. [KC-P-031 VIP 组局创建页](../features/club/feature_vip_party/pages/page_vip_party_create/README.md)
3. [KC-P-032 局长组局管理页](../features/club/feature_vip_party/pages/page_vip_party_management/README.md)
4. [KC-F-024 VIP 组局功能契约](../features/club/feature_vip_party/README.md)

已批准的入场凭证页面：

1. [KC-P-033 入场凭证页](../features/club/feature_admission_ticket/pages/page_admission_ticket/README.md)
2. [KC-F-025 入场凭证功能契约](../features/club/feature_admission_ticket/README.md)

已批准的商业功能页面：

1. [KC-P-034 扫码点单商品/购物车页](../features/commerce/feature_scan_ordering/pages/page_scan_ordering_cart/README.md)
2. [KC-P-035 点单确认页](../features/commerce/feature_scan_ordering/pages/page_scan_order_confirmation/README.md)
3. [KC-P-036 订单中心页](../features/commerce/feature_order_center/pages/page_order_center/README.md)
4. [KC-P-037 订单详情页](../features/commerce/feature_order_center/pages/page_order_detail/README.md)
5. [KC-P-038 支付处理与结果页](../features/commerce/feature_payment/pages/page_payment_result/README.md)

已批准的内容与资产页面：

1. [KC-P-013 短视频/作品流页](../features/content/feature_content_feed/pages/page_content_feed/README.md)
2. [KC-P-039 钱包与资产流水页](../features/membership_wallet/feature_asset_ledger/pages/page_asset_ledger/README.md)

当前待用户评审的设置与安全页面：

1. [KC-P-043 设置页](../features/profile_settings/feature_settings_security/pages/page_settings/README.md)
2. [KC-P-044 支付安全页](../features/profile_settings/feature_settings_security/pages/page_payment_security/README.md)
3. [KC-P-045 账号注销页](../features/profile_settings/feature_settings_security/pages/page_account_deletion/README.md)
4. [KC-P-046 关于与法律文档页](../features/profile_settings/feature_settings_security/pages/page_about_legal/README.md)

## 与迁移资料的关系

- 旧版现状与缺陷以 [迁移交接包](../migration/README.md) 为准。
- V2 架构与功能规划以本目录为准。
- 单个功能或页面的最终需求，以 `docs/features/<业务域>/<功能或页面>/` 内的评审文档为准。
- API v2 的 OpenAPI 契约完成后，应成为客户端接口字段的唯一事实来源。

## 当前总原则

- **已确认事实**：V2 使用 Flutter 建设 iOS/Android 客户端。
- **已确认事实**：旧版微信小程序继续承担稳定业务，并逐步接入 API v2。
- **当前建议**：Flutter 项目采用 feature-first、领域分块、分层依赖。
- **当前建议**：文档与 UI Mock 先覆盖本期确认的全部范围；整 App UI 验收后，真实接入再按可验证的纵向业务闭环逐项推进。
- **已确认事实**：每个功能或页面必须有独立目录并先完成设计文档，之后才能开发。
- **已确认事实**：本期 App 全部功能和页面文档批准后，先用 Mock/Fake 完成 UI 和整 App 流程模拟；全局 UI 流程验收前不得连接真实超级接口、WebSocket 或生产 SDK。
