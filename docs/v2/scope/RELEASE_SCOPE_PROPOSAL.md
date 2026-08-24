# Flutter V2 本期功能与页面范围基线

- 状态：`M0 Scope Frozen`
- 用户确认日期：2026-08-24
- 冻结范围：46 个普通会员主体页面 + D4 私人储物柜 2 页，共 48 页

## 1. 范围原则

- **已确认事实**：Flutter 首发是普通会员 App，不把员工、财务、代理和超级管理员后台混入同一个客户端。
- **已确认事实**：保留 KingClub 的消费差异化能力：会员审核、一起玩 AA、VIP 组局、扫码点单、支付、入场和私人储物柜。
- **已确认事实**：首发保留好友、会话和稳定单聊；完整群管理本期暂缓。
- **已确认事实**：短视频浏览进入首发，作品发布本期暂缓。
- **已确认事实**：所有纳入页面先逐页完成文档，再统一做 UI Mock；整 App UI 验收前不接真实服务。

## 2. 本期功能清单

| 功能 ID | 业务域 | 独立功能文档 | docStatus | 本期处理 |
|---|---|---|---|---|
| KC-F-001 | foundation | [应用启动](../../features/foundation/feature_app_bootstrap/README.md) | Approved for Development | 纳入 |
| KC-F-002 | foundation | [导航](../../features/foundation/feature_navigation/README.md) | Approved for Development | 纳入 |
| KC-F-003 | foundation | [设计系统](../../features/foundation/feature_design_system/README.md) | Approved for Development | 纳入 |
| KC-F-004 | foundation | [网络与超级接口端口](../../features/foundation/feature_networking/README.md) | In Review | 仅文档和 Fake |
| KC-F-005 | foundation | [会话持久化](../../features/foundation/feature_session_persistence/README.md) | In Review | 仅文档和 Fake |
| KC-F-006 | foundation | [可观测性](../../features/foundation/feature_observability/README.md) | In Review | 仅文档和 Fake |
| KC-F-007 | foundation | [App Shell](../../features/foundation/feature_app_shell/README.md) | Approved for Development | 纳入 |
| KC-F-008 | foundation | [Mock Runtime](../../features/foundation/feature_mock_runtime/README.md) | Draft | 纳入 |
| KC-F-009 | foundation | [原生能力与权限](../../features/foundation/feature_native_capabilities/README.md) | Draft | 先定义 Fake/权限状态 |
| KC-F-010 | identity | [登录与鉴权会话](../../features/identity/feature_login_session/README.md) | Approved for Development | 纳入 |
| KC-F-011 | identity | [会员注册与准入](../../features/identity/feature_member_onboarding/README.md) | Approved for Development | 纳入 |
| KC-F-012 | home | [首页聚合](../../features/home/feature_home_hub/README.md) | Approved for Development | 纳入 |
| KC-F-013 | home | [安全扫码分流](../../features/home/feature_safe_scanner/README.md) | Approved for Development | 纳入 |
| KC-F-014 | content | [短视频/作品浏览](../../features/content/feature_content_feed/README.md) | Draft | 只读浏览；不含发布 |
| KC-F-015 | social | [通讯录](../../features/social/feature_contacts/README.md) | Draft | 纳入 |
| KC-F-016 | social | [好友关系](../../features/social/feature_friendship/README.md) | Draft | 纳入 |
| KC-F-017 | social | [用户主页](../../features/social/feature_user_profile/README.md) | Draft | 纳入 |
| KC-F-018 | social | [关系控制](../../features/social/feature_relationship_controls/README.md) | Draft | 纳入 |
| KC-F-019 | messaging | [会话列表](../../features/messaging/feature_conversation_list/README.md) | Draft | 纳入 |
| KC-F-020 | messaging | [系统通知](../../features/messaging/feature_system_notifications/README.md) | Draft | 纳入 |
| KC-F-021 | messaging | [稳定单聊](../../features/messaging/feature_direct_chat/README.md) | Draft | 不含完整群管理 |
| KC-F-022 | messaging | [实时传输端口](../../features/messaging/feature_realtime_transport/README.md) | In Review | 仅文档和 Fake |
| KC-F-023 | club | [一起玩 AA](../../features/club/feature_aa_reservation/README.md) | Draft | 纳入 |
| KC-F-024 | club | [VIP 组局](../../features/club/feature_vip_party/README.md) | Draft | 纳入 |
| KC-F-025 | club | [入场凭证](../../features/club/feature_admission_ticket/README.md) | Draft | 纳入 |
| KC-F-026 | club | [私人储物柜](../../features/club/feature_private_storage/README.md) | Draft | 纳入（D4 已确认） |
| KC-F-027 | commerce | [扫码点单](../../features/commerce/feature_scan_ordering/README.md) | Draft | 纳入 |
| KC-F-028 | commerce | [订单中心](../../features/commerce/feature_order_center/README.md) | Draft | 纳入；V2 新补 |
| KC-F-029 | commerce | [支付](../../features/commerce/feature_payment/README.md) | Draft | 纳入 |
| KC-F-030 | membership_wallet | [资产流水](../../features/membership_wallet/feature_asset_ledger/README.md) | Draft | 只读；不含转赠 |
| KC-F-031 | profile_settings | [个人中心](../../features/profile_settings/feature_profile_center/README.md) | In Review | 纳入 |
| KC-F-032 | profile_settings | [设置与安全](../../features/profile_settings/feature_settings_security/README.md) | Draft | 纳入 |

以上 32 项均已建立独立功能目录；目录建立只代表进入文档设计队列，不代表允许开发。

## 3. 本期 48 个逻辑页面

`docStatus` 只描述文档状态；除现有四个登录页外，下表均需创建独立目录后才能评审。

### 3.1 Foundation 与身份（10）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-001 | 启动鉴权页 | 已有 `page_auth_bootstrap` | Approved for Development |
| KC-P-002 | 手机号登录页 | 已有 `page_mobile_login` | Approved for Development |
| KC-P-003 | 验证码页 | 已有 `page_sms_verification` | Approved for Development |
| KC-P-004 | 协议确认页 | 已有 `page_terms_consent` | Approved for Development |
| KC-P-005 | 实名与成年核验页 | 旧 `regist2` | Approved for Development |
| KC-P-006 | 会员形象资料页 | 旧 `regist3` | Approved for Development |
| KC-P-007 | 着装与音乐偏好页 | 旧 `regist4` | Approved for Development |
| KC-P-008 | 酒类与活动偏好页 | 旧 `regist5` | Approved for Development |
| KC-P-009 | 会员审核状态页 | 替代参数化 `success` | Approved for Development |
| KC-P-010 | App Shell/底部导航容器 | 拆自旧 `index` | Approved for Development |

### 3.2 首页与内容浏览（3）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-011 | 首页 | 拆自旧 `index` 首页 | Approved for Development |
| KC-P-012 | 扫码识别与安全分流页 | 好友码、桌码、入场码 allowlist | Approved for Development |
| KC-P-013 | 短视频/作品流页 | 旧 `index` 视频 tab + `openVideo` | Draft |

### 3.3 社交关系（8）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-014 | 通讯录页 | 拆自旧 `index` | Draft |
| KC-P-015 | 添加好友/扫码页 | 旧 `addfriend` | Draft |
| KC-P-016 | 好友申请列表页 | 旧 `newfriend` | Draft |
| KC-P-017 | 用户主页 | 合并 `friendinfo`、`newfriendInfo`、`userInfo` 的状态 | Draft |
| KC-P-018 | 发送好友申请页 | 旧 `createfriendinfo` | Draft |
| KC-P-019 | 好友备注页 | 旧 `friendinfo2` | Draft |
| KC-P-020 | 关系权限页 | 旧 `friendinfo3` | Draft |
| KC-P-021 | 黑名单页 | 旧 `blacklist` | Draft |

### 3.4 消息（5）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-022 | 会话列表页 | 拆自旧 `index` | Draft |
| KC-P-023 | 系统通知页 | 旧 `sysmessage` | Draft |
| KC-P-024 | 单聊页 | 从旧 `chat` 收敛首发消息类型 | Draft |
| KC-P-025 | 单聊详情页 | 从旧 `chat_more` 收敛 | Draft |
| KC-P-026 | 联系人选择页 | 转发消息、发送组局邀请 | Draft |

### 3.5 到店、组局与入场（7）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-027 | 一起玩 AA 预订页 | 旧 `Choose` | Draft |
| KC-P-028 | AA 卡座套餐详情页 | 旧 `order` | Draft |
| KC-P-029 | AA 确认订单页 | 旧 `order2` | Draft |
| KC-P-030 | VIP 组局列表/详情页 | 旧 `Choose2` | Draft |
| KC-P-031 | VIP 组局创建页 | 旧 `vip-order` | Draft |
| KC-P-032 | 局长组局管理页 | 旧 `order-manage` | Draft |
| KC-P-033 | 入场凭证页 | 旧 `ticket` | Draft |

### 3.6 点单、订单与支付（5）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-034 | 扫码点单商品/购物车页 | 旧 `shoping` | Draft |
| KC-P-035 | 点单确认页 | 旧 `shoping2` | Draft |
| KC-P-036 | 订单中心页 | V2 新补：统一查看 AA、组局和点单订单 | Draft |
| KC-P-037 | 订单详情页 | 合并消费者 `shoping3` 等状态，不复用管理详情 | Draft |
| KC-P-038 | 支付处理与结果页 | 重构旧 `pay`，禁止客户端确认金额/成功 | Draft |

### 3.7 钱包、个人与设置（8）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-039 | 钱包与资产流水页 | 旧 `mybalance` | Draft |
| KC-P-040 | 我的主页 | 拆自旧 `index` 我的 tab | In Review |
| KC-P-041 | 编辑个人资料页 | 旧 `myinfo` | In Review |
| KC-P-042 | 个人二维码页 | 旧 `mycode` 个人模式 | In Review |
| KC-P-043 | 设置页 | 旧 `setting`，改为客户端固定 allowlist | Draft |
| KC-P-044 | 支付安全页 | 旧 `modiffypwd` | Draft |
| KC-P-045 | 账号注销页 | 旧 `del_user_account` | Draft |
| KC-P-046 | 关于与法律文档页 | 合并 `about` 与只读协议查看 | Draft |

### 3.8 私人储物柜（2）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-047 | 私人储物柜页 | 拆自旧 `index` 储物柜 tab | Draft |
| KC-P-048 | 存酒/物品取件码页 | 旧 `savecode`；员工交付不在会员 App | Draft |

## 4. 可选包确认结果

| 决策包 | 确认结果 | 页面数 | 处理 |
|---|---|---:|---|
| D1 完整群聊与群管理 | 本期暂缓 | 6 | 不建立本期页面目录和路由；以后独立变更评审 |
| D2 作品发布 | 本期暂缓 | 1 | 保留短视频浏览，不建立发布页面目录和上传流程 |
| D3 红包与金币转赠 | 本期暂缓 | 2 | 不建立本期资产写入与聊天入口 |
| D4 私人储物柜 | 本期纳入 | 2 | 进入 KC-P-047～048；员工扫码交付仍移出会员 App |

本期页面总数固定为 48。D1～D3 若未来加入，必须先变更本基线并重新评估全局 UI 门禁。

## 5. 明确不进入消费者 Flutter 首发

### 5.1 角色后台

- 员工存酒交付、座位管理。
- 管理员/代理面板、管理码、顾客列表/详情。
- 人工充值、管理端订单详情、提成流水、代理设置、佣金提现。
- 系统配置、运营推广内容和富文本 CMS。

这些能力以后应评审为独立员工/运营 App 或 Web 管理端，不应通过隐藏菜单塞入普通会员 App。

### 5.2 旧平台或技术页面

- 参数化通用成功/失败页：改为各功能自己的状态。
- APK 下载页：由 App Store、Android 应用市场或正式分发渠道替代。
- `logs` 调试页和摇一摇计分实验页。
- 服务端动态下发任意客户端路由。

### 5.3 后续单独确认

- `bind_account` 的真实业务语义：如果是代理绑定，归运营域；如果是跨 App 身份绑定，必须重新做统一身份与安全设计。
- 旧聊天记录、订单、余额、金币、实名资料各自迁移的历史范围。
- 退款/售后虽然旧版没有完整独立页面，但若首发支持真实支付，必须在接入前决定由 App、客服还是线下流程承接。

## 6. M0 冻结记录

- 用户已于 2026-08-24 回复“按建议确认”。
- 48 个页面是本期唯一允许进入设计队列的消费者页面。
- 功能/页面目录建立后默认保持 `Draft`；建立目录不代表文档已批准。
- 新增、删除或重新纳入 D1～D3 必须更新本基线、覆盖账本、导航和 Roadmap。
