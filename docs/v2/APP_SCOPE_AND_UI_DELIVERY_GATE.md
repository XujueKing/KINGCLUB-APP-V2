# App 范围、页面覆盖与 UI 交付门禁

- 文档状态：`M2 Change In Progress — Chat Extensions Added, Awaiting Revalidation`
- 决策日期：2026-08-24
- 作用：作为本期 Flutter App 是否允许进入 UI、是否允许真实接入的唯一覆盖账本

## 1. 已确认交付顺序

```text
冻结本期功能/页面总清单
  -> 每个功能和页面独立文档批准
  -> 创建 Flutter UI，只接 Mock/Fake
  -> 模拟本期整 App 主流程、异常流程和返回路径
  -> 用户完成 UI 验收，项目标记 UI Flow Approved
  -> 按批准契约接真实超级接口、WebSocket 和 SDK
```

禁止事项：

- 不允许页面文档未批准就创建 UI。
- 不允许因为某一个页面已批准就提前开始整 App UI。
- 不允许 UI 阶段访问真实开发、测试或生产服务。
- 不允许单个页面 Mock 完成后提前连接真实接口。
- 不允许用真实接口返回反向决定 UI、状态机或页面流程。

## 2. 覆盖账本字段

本期范围冻结后，每个功能和页面都必须进入账本：

| 字段 | 说明 |
|---|---|
| `scopeId` | 稳定功能/页面编号 |
| `domain` | foundation、identity、home、social 等业务域 |
| `featureDoc` | 独立功能目录链接 |
| `pageDoc` | 独立页面目录链接；功能级能力可为空 |
| `inReleaseScope` | 是否纳入本期，退出范围必须记录原因 |
| `docStatus` | Draft / In Review / Approved for Development |
| `designVersion` | UI 设计稿或线框版本 |
| `mockScenarios` | Mock/Fake 场景编号与覆盖状态 |
| `uiStatus` | Not Started / In Progress / UI Mock Implemented / UI Flow Approved |
| `integrationStatus` | Blocked / Integrated / Implemented / Accepted |

## 3. 当前覆盖状态

旧版 69 个物理路由已经完成逐项审计，详见 [本期范围评审包](scope/README.md)。用户已于 2026-08-24 确认“46 个普通会员主体页面 + D4 私人储物柜 2 页”，本期共冻结 48 页。2026-08-29 用户进一步确认在 KC-P-024 内恢复 D3 的红包、金币和礼物 UI/Mock，但不新增页面、不接真实资产交易；D1 完整群聊、D2 作品发布、D3 真实交易仍暂缓，角色后台与旧平台页面移出消费者 App。

| 业务域 | 当前事实 | 下一文档动作 |
|---|---|---|
| foundation | 九个 Foundation 模块与 Design System v1 均已批准；Flutter 工程与第一批 Fake 已创建 | 继续实现 Theme、路由、Fake Runtime 和状态测试，不接真实 adapter |
| identity/login | 9 页已冻结并批准；4 个登录页与 5 个会员准入页 UI Mock 均已进入实现 | 补全 AUTH/ONB 全部异常状态与多尺寸验收 |
| home | 首页旧版 UI 与五 Tab 复刻规范已批准；安全扫码仍为首页入口 | 开始复刻 UI；保持真实首页、相机和扫码接口阻断 |
| social | 8 页已批准；通讯录进入 UI Mock 实现 | 继续好友申请与关系页面 UI；保持真实社交接口阻断 |
| messaging | 会话、系统通知、稳定单聊共 5 页、实时传输 port 与聊天扩展 UI/Mock 已批准 | 补齐 KC-F-033 UI 与回归；保持真实消息/资产服务阻断，不得引入 D1 群管理 |
| content | 短视频浏览 1 页已批准并进入 UI Mock 实现 | 保持真实内容/媒体能力阻断；不得引入 D2 发布 |
| club | AA、VIP 组局、入场凭证与私人储物柜共 9 页均已批准 | 后续按 UI 批次实现；员工交付不纳入 |
| commerce | 点单、确认、订单中心、详情和支付共 5 页已批准 | 保持真实订单/支付能力阻断，等待全局门禁 |
| membership_wallet | 资产流水 1 页已批准 | 保持真实资产能力阻断；不得引入 D3 资产转赠 |
| profile_settings | 个人中心、设置、安全、注销、关于共 7 页均已批准 | 后续按 UI 批次实现；账号绑定不纳入 |
| operations | 已确认移出消费者首发 | 不建立本期页面目录或路由 |

M0 范围与 M1 文档全局门禁已经完成；Flutter UI/Mock 已于 2026-08-26 开始，真实接入仍保持 `Blocked`。

截至 2026-08-29，冻结范围 48/48 页均已达到 `UI Mock Implemented`，J01～J07 已完成自动化与 Android 真机阶段验收；追加的五阶段技术验收已完成 294/294 自动化、200% 字体和系统返回复验，没有剩余 P0/P1/P2 UI 阻断项。项目已达到用户 `UI Flow Approved` 决策的技术前置条件，但尚未获得用户明确批准，因此所有真实接入继续保持 `Blocked`。证据见 [2026-08-29 全局 UI 收口审计](../features/foundation/feature_mock_runtime/audit/2026-08-29-global-closure/README.md)与[五阶段 UI 验收](../features/foundation/feature_mock_runtime/audit/2026-08-29-ui-flow-approval/README.md)。

## 4. M0 冻结功能覆盖账本

以下 33 项全部为 `inReleaseScope=true`，并已建立独立目录。功能状态不等同于页面状态；只有功能与其名下全部页面均批准后，才计入 M1 完成。

| Scope ID | 业务域 | 独立功能文档 | docStatus |
|---|---|---|---|
| KC-F-001 | foundation | [应用启动](../features/foundation/feature_app_bootstrap/README.md) | Approved for Development |
| KC-F-002 | foundation | [导航](../features/foundation/feature_navigation/README.md) | Approved for Development |
| KC-F-003 | foundation | [设计系统](../features/foundation/feature_design_system/README.md) | Approved for Development |
| KC-F-004 | foundation | [网络与超级接口端口](../features/foundation/feature_networking/README.md) | Approved for Development |
| KC-F-005 | foundation | [会话持久化](../features/foundation/feature_session_persistence/README.md) | Approved for Development |
| KC-F-006 | foundation | [可观测性](../features/foundation/feature_observability/README.md) | Approved for Development |
| KC-F-007 | foundation | [App Shell](../features/foundation/feature_app_shell/README.md) | Approved for Development |
| KC-F-008 | foundation | [Mock Runtime](../features/foundation/feature_mock_runtime/README.md) | Approved for Development |
| KC-F-009 | foundation | [原生能力与权限](../features/foundation/feature_native_capabilities/README.md) | Approved for Development |
| KC-F-010 | identity | [登录与鉴权会话](../features/identity/feature_login_session/README.md) | Approved for Development |
| KC-F-011 | identity | [会员注册与准入](../features/identity/feature_member_onboarding/README.md) | Approved for Development |
| KC-F-012 | home | [首页聚合](../features/home/feature_home_hub/README.md) | Approved for Development |
| KC-F-013 | home | [安全扫码分流](../features/home/feature_safe_scanner/README.md) | Approved for Development |
| KC-F-014 | content | [短视频/作品浏览](../features/content/feature_content_feed/README.md) | Approved for Development |
| KC-F-015 | social | [通讯录](../features/social/feature_contacts/README.md) | Approved for Development |
| KC-F-016 | social | [好友关系](../features/social/feature_friendship/README.md) | Approved for Development |
| KC-F-017 | social | [用户主页](../features/social/feature_user_profile/README.md) | Approved for Development |
| KC-F-018 | social | [关系控制](../features/social/feature_relationship_controls/README.md) | Approved for Development |
| KC-F-019 | messaging | [会话列表](../features/messaging/feature_conversation_list/README.md) | Approved for Development |
| KC-F-020 | messaging | [系统通知](../features/messaging/feature_system_notifications/README.md) | Approved for Development |
| KC-F-021 | messaging | [稳定单聊](../features/messaging/feature_direct_chat/README.md) | Approved for Development |
| KC-F-022 | messaging | [实时传输端口](../features/messaging/feature_realtime_transport/README.md) | Approved for Development |
| KC-F-023 | club | [一起玩 AA](../features/club/feature_aa_reservation/README.md) | Approved for Development |
| KC-F-024 | club | [VIP 组局](../features/club/feature_vip_party/README.md) | Approved for Development |
| KC-F-025 | club | [入场凭证](../features/club/feature_admission_ticket/README.md) | Approved for Development |
| KC-F-026 | club | [私人储物柜](../features/club/feature_private_storage/README.md) | Approved for Development |
| KC-F-027 | commerce | [扫码点单](../features/commerce/feature_scan_ordering/README.md) | Approved for Development |
| KC-F-028 | commerce | [订单中心](../features/commerce/feature_order_center/README.md) | Approved for Development |
| KC-F-029 | commerce | [支付](../features/commerce/feature_payment/README.md) | Approved for Development |
| KC-F-030 | membership_wallet | [资产流水](../features/membership_wallet/feature_asset_ledger/README.md) | Approved for Development |
| KC-F-031 | profile_settings | [个人中心](../features/profile_settings/feature_profile_center/README.md) | Approved for Development |
| KC-F-032 | profile_settings | [设置与安全](../features/profile_settings/feature_settings_security/README.md) | Approved for Development |
| KC-F-033 | messaging | [聊天扩展面板与礼物 Mock](../features/messaging/feature_chat_extensions/README.md) | Approved for Development |

## 5. M0 冻结页面覆盖账本

以下 48 项全部为 `inReleaseScope=true`。`designVersion` 和 `mockScenarios` 未完成前页面保持 Draft；`integrationStatus` 在项目达到 `UI Flow Approved` 前固定为 Blocked。

| Scope ID | 业务域 | 功能文档 | 页面文档 | docStatus | designVersion | mockScenarios | uiStatus | integrationStatus |
|---|---|---|---|---|---|---|---|---|
| KC-P-001 | identity | [feature_login_session](../features/identity/feature_login_session/README.md) | [启动鉴权页](../features/identity/feature_login_session/pages/page_auth_bootstrap/README.md) | Approved for Development | Auth Wireframe v1 | 已定义（页面文档） | UI Mock Implemented | Blocked |
| KC-P-002 | identity | [feature_login_session](../features/identity/feature_login_session/README.md) | [手机号登录页](../features/identity/feature_login_session/pages/page_mobile_login/README.md) | Approved for Development | Auth Wireframe v1 | 已定义（页面文档） | UI Mock Implemented | Blocked |
| KC-P-003 | identity | [feature_login_session](../features/identity/feature_login_session/README.md) | [验证码页](../features/identity/feature_login_session/pages/page_sms_verification/README.md) | Approved for Development | Auth Wireframe v1 | 已定义（页面文档） | UI Mock Implemented | Blocked |
| KC-P-004 | identity | [feature_login_session](../features/identity/feature_login_session/README.md) | [协议确认页](../features/identity/feature_login_session/pages/page_terms_consent/README.md) | Approved for Development | Auth Wireframe v1 | 已定义（页面文档） | UI Mock Implemented | Blocked |
| KC-P-005 | identity | [feature_member_onboarding](../features/identity/feature_member_onboarding/README.md) | [实名与成年核验页](../features/identity/feature_member_onboarding/pages/page_real_name_adult_verification/README.md) | Approved for Development | Onboarding Wireframe v1 / Step 1 | ONB-M02～04、13～15 已自动化覆盖 | UI Mock Implemented | Blocked |
| KC-P-006 | identity | [feature_member_onboarding](../features/identity/feature_member_onboarding/README.md) | [会员形象资料页](../features/identity/feature_member_onboarding/pages/page_membership_image_submission/README.md) | Approved for Development | Onboarding Wireframe v1 / Step 2 | ONB-M05～06、11、13 | UI Mock Implemented | Blocked |
| KC-P-007 | identity | [feature_member_onboarding](../features/identity/feature_member_onboarding/README.md) | [着装与音乐偏好页](../features/identity/feature_member_onboarding/pages/page_style_music_preferences/README.md) | Approved for Development | Onboarding Wireframe v1 / Step 3 | ONB-M07～08、13～15 | UI Mock Implemented | Blocked |
| KC-P-008 | identity | [feature_member_onboarding](../features/identity/feature_member_onboarding/README.md) | [酒类与活动偏好页](../features/identity/feature_member_onboarding/pages/page_drink_event_preferences/README.md) | Approved for Development | Onboarding Wireframe v1 / Step 4 | ONB-M07～09、13～15 | UI Mock Implemented | Blocked |
| KC-P-009 | identity | [feature_member_onboarding](../features/identity/feature_member_onboarding/README.md) | [会员审核状态页](../features/identity/feature_member_onboarding/pages/page_membership_review_status/README.md) | Approved for Development | Onboarding Wireframe v1 / Review | ONB-M10～14 | UI Mock Implemented | Blocked |
| KC-P-010 | foundation | [feature_app_shell](../features/foundation/feature_app_shell/README.md) | [App Shell/底部导航容器](../features/foundation/feature_app_shell/pages/page_app_shell/README.md) | Approved for Development | Legacy Shell Replica v1 | SHELL-M01～M12 | UI Mock Implemented | Blocked |
| KC-P-011 | home | [feature_home_hub](../features/home/feature_home_hub/README.md) | [首页](../features/home/feature_home_hub/pages/page_home/README.md) | Approved for Development | Legacy Home Replica v1 / Component Content v1 | HOME-M01～M14 已自动化覆盖 | UI Mock Implemented | Blocked |
| KC-P-012 | home | [feature_safe_scanner](../features/home/feature_safe_scanner/README.md) | [扫码识别与安全分流页](../features/home/feature_safe_scanner/pages/page_safe_scanner/README.md) | Approved for Development | Safe Scanner Wireframe v1 | SCAN-M01～M16 已自动化覆盖 | UI Mock Implemented | Blocked |
| KC-P-013 | content | [feature_content_feed](../features/content/feature_content_feed/README.md) | [短视频/作品流页](../features/content/feature_content_feed/pages/page_content_feed/README.md) | Approved for Development | Content Feed Wireframe v1 | FEED-M01～M20 | UI Mock Implemented | Blocked |
| KC-P-014 | social | [feature_contacts](../features/social/feature_contacts/README.md) | [通讯录页](../features/social/feature_contacts/pages/page_contacts/README.md) | Approved for Development | Contacts Wireframe v1 | CONTACT-M01～M10 | UI Mock Implemented | Blocked |
| KC-P-015 | social | [feature_friendship](../features/social/feature_friendship/README.md) | [添加好友入口页](../features/social/feature_friendship/pages/page_add_friend/README.md) | Approved for Development | Friendship Wireframe v1 / Add | FRIEND-M01～M03 | UI Mock Implemented | Blocked |
| KC-P-016 | social | [feature_friendship](../features/social/feature_friendship/README.md) | [好友申请列表页](../features/social/feature_friendship/pages/page_friend_requests/README.md) | Approved for Development | Friendship Wireframe v1 / Requests | FRIEND-M04～M05、M09～M13 | UI Mock Implemented | Blocked |
| KC-P-017 | social | [feature_user_profile](../features/social/feature_user_profile/README.md) | [用户主页](../features/social/feature_user_profile/pages/page_user_profile/README.md) | Approved for Development | Social User Profile Wireframe v1 | PROFILE-SOC-M01～M12 | UI Mock Implemented | Blocked |
| KC-P-018 | social | [feature_friendship](../features/social/feature_friendship/README.md) | [发送好友申请页](../features/social/feature_friendship/pages/page_send_friend_request/README.md) | Approved for Development | Friendship Wireframe v1 / Send | FRIEND-M06～M07、M10～M13 | UI Mock Implemented | Blocked |
| KC-P-019 | social | [feature_relationship_controls](../features/social/feature_relationship_controls/README.md) | [好友备注页](../features/social/feature_relationship_controls/pages/page_friend_remark/README.md) | Approved for Development | Relationship Wireframe v1 / Remark | REL-M01～M03、M11～M12 | UI Mock Implemented | Blocked |
| KC-P-020 | social | [feature_relationship_controls](../features/social/feature_relationship_controls/README.md) | [关系权限页](../features/social/feature_relationship_controls/pages/page_relationship_permissions/README.md) | Approved for Development | Relationship Wireframe v1 / Permissions | REL-M04～M08、M10～M12 | UI Mock Implemented | Blocked |
| KC-P-021 | social | [feature_relationship_controls](../features/social/feature_relationship_controls/README.md) | [黑名单页](../features/social/feature_relationship_controls/pages/page_blacklist/README.md) | Approved for Development | Relationship Wireframe v1 / Blacklist | REL-M09～M12 | UI Mock Implemented | Blocked |
| KC-P-022 | messaging | [feature_conversation_list](../features/messaging/feature_conversation_list/README.md) | [会话列表页](../features/messaging/feature_conversation_list/pages/page_conversations/README.md) | Approved for Development | Legacy Conversations Replica v1 | CONV-M01～M11 | UI Mock Implemented | Blocked |
| KC-P-023 | messaging | [feature_system_notifications](../features/messaging/feature_system_notifications/README.md) | [系统通知页](../features/messaging/feature_system_notifications/pages/page_system_notifications/README.md) | Approved for Development | Legacy System Notifications Replica v1 | NOTICE-M01～M10 | UI Mock Implemented | Blocked |
| KC-P-024 | messaging | [feature_direct_chat](../features/messaging/feature_direct_chat/README.md) | [单聊页](../features/messaging/feature_direct_chat/pages/page_direct_chat/README.md) | Approved for Development | Legacy Direct Chat Replica v1 | CHAT-M01～M13、M18 | UI Mock Implemented | Blocked |
| KC-P-025 | messaging | [feature_direct_chat](../features/messaging/feature_direct_chat/README.md) | [单聊详情页](../features/messaging/feature_direct_chat/pages/page_direct_chat_details/README.md) | Approved for Development | Legacy Chat Details Replica v1 | CHAT-M14～M16、M18 | UI Mock Implemented | Blocked |
| KC-P-026 | messaging | [feature_direct_chat](../features/messaging/feature_direct_chat/README.md) | [联系人选择页](../features/messaging/feature_direct_chat/pages/page_contact_selector/README.md) | Approved for Development | Legacy Contact Selector Replica v1 | CHAT-M08～M09、M17～M18 | UI Mock Implemented | Blocked |
| KC-P-027 | club | [feature_aa_reservation](../features/club/feature_aa_reservation/README.md) | [一起玩 AA 预订页](../features/club/feature_aa_reservation/pages/page_aa_reservations/README.md) | Approved for Development | AA Reservation Legacy Replica v2 / Landing | AA-M01～M05、M08、M16～M20 已自动化与 Android 验收 | UI Mock Implemented | Blocked |
| KC-P-028 | club | [feature_aa_reservation](../features/club/feature_aa_reservation/README.md) | [AA 卡座套餐详情页](../features/club/feature_aa_reservation/pages/page_aa_package_detail/README.md) | Approved for Development | AA Reservation Legacy Replica v2 / Package | AA-M06～M08、M17～M20 已自动化与 Android 验收 | UI Mock Implemented | Blocked |
| KC-P-029 | club | [feature_aa_reservation](../features/club/feature_aa_reservation/README.md) | [AA 确认订单页](../features/club/feature_aa_reservation/pages/page_aa_order_confirmation/README.md) | Approved for Development | AA Reservation Legacy Replica v2 / Confirmation | AA-M09～M20 已自动化与 Android 验收 | UI Mock Implemented | Blocked |
| KC-P-030 | club | [feature_vip_party](../features/club/feature_vip_party/README.md) | [VIP 组局列表/详情页](../features/club/feature_vip_party/pages/page_vip_party_detail/README.md) | Approved for Development | VIP Party Legacy Replica v2 / Browse | PARTY-M01～M09、M21～M24 已自动化与 Android 真机验收 | UI Mock Implemented | Blocked |
| KC-P-031 | club | [feature_vip_party](../features/club/feature_vip_party/README.md) | [VIP 组局创建页](../features/club/feature_vip_party/pages/page_vip_party_create/README.md) | Approved for Development | VIP Party Legacy Replica v2 / Create | PARTY-M10～M15、M22～M24 已自动化验收 | UI Mock Implemented | Blocked |
| KC-P-032 | club | [feature_vip_party](../features/club/feature_vip_party/README.md) | [局长组局管理页](../features/club/feature_vip_party/pages/page_vip_party_management/README.md) | Approved for Development | Legacy Replica v2 / Consumer Host Management | PARTY-M16～M24 已自动化与 Android 真机验收 | UI Mock Implemented | Blocked |
| KC-P-033 | club | [feature_admission_ticket](../features/club/feature_admission_ticket/README.md) | [入场凭证页](../features/club/feature_admission_ticket/pages/page_admission_ticket/README.md) | Approved for Development | Legacy Ticket Replica v2 / Dynamic Credential | TICKET-M01～M20 已自动化与 Android 真机验收 | UI Mock Implemented | Blocked |
| KC-P-034 | commerce | [feature_scan_ordering](../features/commerce/feature_scan_ordering/README.md) | [扫码点单商品/购物车页](../features/commerce/feature_scan_ordering/pages/page_scan_ordering_cart/README.md) | Approved for Development | Legacy Shoping Replica v2 / Cart | ORDERING-M01～M12、M19～M20 已自动化与 Android 真机验收 | UI Mock Implemented | Blocked |
| KC-P-035 | commerce | [feature_scan_ordering](../features/commerce/feature_scan_ordering/README.md) | [点单确认页](../features/commerce/feature_scan_ordering/pages/page_scan_order_confirmation/README.md) | Approved for Development | Legacy Shoping2 Replica v2 / Confirmation | ORDERING-M11～M20 已自动化与 Android 真机验收 | UI Mock Implemented | Blocked |
| KC-P-036 | commerce | [feature_order_center](../features/commerce/feature_order_center/README.md) | [订单中心页](../features/commerce/feature_order_center/pages/page_order_center/README.md) | Approved for Development | Legacy Orders Consolidation v2 / List | ORDERS-M01～M06、M16～M18 已自动化与 Android 真机验收 | UI Mock Implemented | Blocked |
| KC-P-037 | commerce | [feature_order_center](../features/commerce/feature_order_center/README.md) | [订单详情页](../features/commerce/feature_order_center/pages/page_order_detail/README.md) | Approved for Development | Legacy Order Detail v2 / Fake Flow | ORDERS-M07～M18 已自动化与 Android 真机验收 | UI Mock Implemented | Blocked |
| KC-P-038 | commerce | [feature_payment](../features/commerce/feature_payment/README.md) | [支付处理与结果页](../features/commerce/feature_payment/pages/page_payment_result/README.md) | Approved for Development | Legacy Payment Result v2 / Fake Orchestration | PAY-M01～M20 已自动化与 Android 真机验收 | UI Mock Implemented | Blocked |
| KC-P-039 | membership_wallet | [feature_asset_ledger](../features/membership_wallet/feature_asset_ledger/README.md) | [钱包与资产流水页](../features/membership_wallet/feature_asset_ledger/pages/page_asset_ledger/README.md) | Approved for Development | Legacy Asset Ledger Replica v2 / Read-only Fake Flow | ASSET-M01～M20 | UI Mock Implemented | Blocked |
| KC-P-040 | profile_settings | [feature_profile_center](../features/profile_settings/feature_profile_center/README.md) | [我的主页](../features/profile_settings/feature_profile_center/pages/page_my_profile/README.md) | Approved for Development | Legacy My Profile Replica v1 | PROFILE-M01～M04、M16～M18 | UI Mock Implemented | Blocked |
| KC-P-041 | profile_settings | [feature_profile_center](../features/profile_settings/feature_profile_center/README.md) | [编辑个人资料页](../features/profile_settings/feature_profile_center/pages/page_edit_profile/README.md) | Approved for Development | Legacy Edit Profile Replica v2 / Complete Fake Flow | PROFILE-M05～M12、M16～M18 | UI Mock Implemented | Blocked |
| KC-P-042 | profile_settings | [feature_profile_center](../features/profile_settings/feature_profile_center/README.md) | [个人二维码页](../features/profile_settings/feature_profile_center/pages/page_personal_qr/README.md) | Approved for Development | Profile Center Wireframe v1 / QR | PROFILE-M13～M18 | UI Mock Implemented | Blocked |
| KC-P-043 | profile_settings | [feature_settings_security](../features/profile_settings/feature_settings_security/README.md) | [设置页](../features/profile_settings/feature_settings_security/pages/page_settings/README.md) | Approved for Development | Settings Wireframe v1 / Hub | SETTINGS-M01～M06、M22 | UI Mock Implemented | Blocked |
| KC-P-044 | profile_settings | [feature_settings_security](../features/profile_settings/feature_settings_security/README.md) | [支付安全页](../features/profile_settings/feature_settings_security/pages/page_payment_security/README.md) | Approved for Development | Settings Wireframe v1 / Payment PIN | SETTINGS-M07～M12、M22 | UI Mock Implemented | Blocked |
| KC-P-045 | profile_settings | [feature_settings_security](../features/profile_settings/feature_settings_security/README.md) | [账号注销页](../features/profile_settings/feature_settings_security/pages/page_account_deletion/README.md) | Approved for Development | Settings Wireframe v1 / Deletion | SETTINGS-M13～M18、M22 | UI Mock Implemented | Blocked |
| KC-P-046 | profile_settings | [feature_settings_security](../features/profile_settings/feature_settings_security/README.md) | [关于与法律文档页](../features/profile_settings/feature_settings_security/pages/page_about_legal/README.md) | Approved for Development | Settings Wireframe v1 / About & Legal | SETTINGS-M19～M22 | UI Mock Implemented | Blocked |
| KC-P-047 | club | [feature_private_storage](../features/club/feature_private_storage/README.md) | [私人储物柜页](../features/club/feature_private_storage/pages/page_private_storage/README.md) | Approved for Development | Private Storage Legacy Replica v1 / List | STORAGE-M01～M07 已自动化与 Android 真机验收 | UI Mock Implemented | Blocked |
| KC-P-048 | club | [feature_private_storage](../features/club/feature_private_storage/README.md) | [存酒/物品取件码页](../features/club/feature_private_storage/pages/page_storage_pickup_code/README.md) | Approved for Development | Private Storage Wireframe v1 / Pickup | STORAGE-M08～M16 已自动化与 Android 真机验收 | UI Mock Implemented | Blocked |

## 6. 进入 UI 的全局条件

- 本期功能/页面清单和不做清单由用户确认。
- 账本中所有 `inReleaseScope=true` 项都有独立目录和可执行验收文档。
- 所有这些项的 `docStatus=Approved for Development`。
- design system、foundation、跨页面导航和 Mock 数据契约已批准。
- 仓库审计不存在未登记页面或功能入口。

满足后才允许执行 `flutter create` 并进入纯 UI/Mock 阶段。

## 7. 进入真实接入的全局条件

- 所有本期页面达到 `UI Mock Implemented`。
- 启动、登录、首页及本期全部业务主流程和异常流程可离线完整演示。
- 用户完成整 App UI 验收并明确批准项目状态 `UI Flow Approved`。
- UI 验收差异已经回写功能/页面文档和 Mock 契约。
- 真实接入计划明确 adapter 替换顺序、测试、灰度和回滚方式。

任一条件缺失时，networking、WebSocket、支付、推送等只能保留端口、Fake 和契约文档，不得连接真实环境。

## 8. 变更控制

- 新增页面必须先加入本期清单并完成文档，不能在 UI 开发中临时增加。
- 删除/合并页面必须记录用户任务去向和导航影响。
- UI Mock 验收后新增功能会撤销当前 `UI Flow Approved`，直到新增范围完成同样流程。
- 真实接入发现契约缺口时回到文档/Mock 阶段修正，不能在 adapter 中偷偷改变页面语义。
