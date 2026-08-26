# V1 路由目录与导航动作

- 文档状态：`Approved for Development`
- 规则：可以先冻结跨模块所需的路由语义；只有已有独立页面文档且通过准入的页面才能实现 builder/page

## 1. 路由分区

| 分区 | 会话要求 | 是否允许外部打开 | V1 恢复策略 |
|---|---|---|---|
| `bootstrap` | `unknown` | 否 | 每次冷启动固定进入 |
| `authFlow` | `anonymous` 或登录恢复中 | 否 | 仅内存，进程结束即销毁 |
| `onboarding` | `authenticated`，会员未完成准入 | 否 | 冷启动复核后进入权威步骤/审核状态 |
| `protectedShell` | `authenticated + membership approved` | 当前不允许 | 冷启动重新鉴权后进入首页根 |

## 2. 首批冻结路由语义

| RouteData 语义名 | location | 分区 | 输入 | 页面准入 | 进入/退出规则 |
|---|---|---|---|---|---|
| `AuthBootstrapRoute` | `/auth/bootstrap` | bootstrap | 无 | 已批准 | 唯一初始路由；只能由 App Root 建立，不入返回栈 |
| `MobileLoginRoute` | `/auth/mobile` | authFlow | 可选内存 `AuthEntryContext` | 已批准 | 匿名入口；不得回到 bootstrap |
| `SmsCodeRoute` | `/auth/code` | authFlow | 必需 `$extra: LoginFlowRef` | 已批准 | K101 明确成功后 replace；无合法 FlowStore 条目则回 mobile |
| `TermsConsentRoute` | `/auth/consent` | authFlow | 必需 `$extra: ConsentRouteContext` | 已批准 | readOnly 使用 push/pop；loginRecovery 使用 replace |
| `AppShellRoute` | 容器，无外部 location | protectedShell | 无 | 已批准 | 只在 approved member 下建立四个分支 |
| `HomeRoute` | `/home` | protectedShell/home | 无 | 已批准 | 登录后的默认主目的地 |
| `ConversationsRoute` | `/messages` | protectedShell/messages | 无 | 已批准 | 消息分支根；仍受 48 页全局门禁约束 |
| `ContentFeedRoute` | `/discover` | protectedShell/discover | 无 | 已批准 | 发现分支根，只读内容 |
| `MyProfileRoute` | `/me` | protectedShell/me | 无 | 已批准 | 我的分支根 |
| `SafeScannerRoute` | `/scan` | protectedShell overlay | 仅内存来源分支引用 | 已批准 | 中央动作或首页打开，关闭回来源分支 |
| `EditProfileRoute` | `/me/edit` | protectedShell/me | 无 | 已批准 | 从我的主页进入；未保存退出需确认 |
| `PersonalQrRoute` | `/me/qr` | protectedShell/me | 无 | 已批准 | 从我的主页进入；禁止外部打开和路由参数 |
| `ContactsRoute` | `/messages/contacts` | protectedShell/messages | 无 | 已批准 | 通讯录子根 |
| `AddFriendRoute` | `/social/add` | protectedShell/messages | 无 | 已批准 | 扫码/个人码固定入口 |
| `FriendRequestsRoute` | `/social/requests` | protectedShell/messages | 无 | 已批准 | 收到与发出申请列表 |
| `UserProfileRoute` | `/social/profile` | protectedShell/messages | `$extra: SocialTargetRef + FriendRequestRef?` | 已批准 | 统一关系状态页；禁止外部打开 |
| `SendFriendRequestRoute` | `/social/request/send` | protectedShell/messages | `$extra: SocialTargetRef` | 已批准 | 仅从已确认目标进入 |
| `FriendRemarkRoute` | `/social/friend/remark` | protectedShell/messages | `$extra: SocialTargetRef` | 已批准 | 仅好友可进入 |
| `RelationshipPermissionsRoute` | `/social/friend/permissions` | protectedShell/messages | `$extra: SocialTargetRef` | 已批准 | 好友或已拉黑关系可进入 |
| `BlacklistRoute` | `/social/blacklist` | protectedShell/messages | 无 | 已批准 | 只列自己主动拉黑的用户 |
| `SystemNotificationsRoute` | `/messages/system` | protectedShell/messages | 无 | 已批准 | 固定系统通知入口 |
| `DirectChatRoute` | `/messages/chat` | protectedShell/messages | `$extra: ConversationRef` | 已批准 | 单聊历史；禁止外部打开 |
| `DirectChatDetailsRoute` | `/messages/chat/details` | protectedShell/messages | `$extra: ConversationRef` | 已批准 | 单聊设置与内嵌搜索 |
| `ContactSelectorRoute` | `/messages/select-contact` | protectedShell/messages overlay | `$extra: ShareIntentRef` | 已批准 | 单人转发/业务卡片确认 |
| `AaReservationsRoute` | `/club/aa` | protectedShell/home | 无 | 已批准 | AA 营业日、已有预订与套餐列表 |
| `AaPackageDetailRoute` | `/club/aa/package` | protectedShell/home | `$extra: AaOfferRef` | 已批准 | 权威套餐投影；禁止外部打开 |
| `AaOrderConfirmationRoute` | `/club/aa/confirm` | protectedShell/home | `$extra: AaQuoteRef` | 已批准 | 权威报价确认；禁止外部打开 |
| `VipPartyDetailRoute` | `/club/parties` | protectedShell/home | 可选 `$extra: PartyRef` | 已批准 | 公开列表与受控详情；禁止外部任意打开私有局 |
| `VipPartyCreateRoute` | `/club/parties/create` | protectedShell/home | `$extra: ServiceDayRef` | 已批准 | 组局草稿与权威报价 |
| `VipPartyManagementRoute` | `/club/parties/manage` | protectedShell/home | `$extra: PartyRef` | 已批准 | 仅当前局长；禁止外部打开 |
| `AdmissionTicketRoute` | `/club/admission` | protectedShell/home | `$extra: AdmissionRef + ScanContextRef?` | 已批准 | 本人动态凭证或受控离场确认；禁止外部打开 |
| `ScanOrderingCartRoute` | `/commerce/ordering` | protectedShell overlay/home | `$extra: OrderingContextRef` | 已批准 | 仅从已验证安全扫码上下文进入 |
| `ScanOrderConfirmationRoute` | `/commerce/ordering/confirm` | protectedShell overlay/home | `$extra: QuoteRef` | 已批准 | 短时报价确认；禁止订单 JSON |
| `OrderCenterRoute` | `/commerce/orders` | protectedShell/me | 无 | 已批准 | 当前会话本人的消费者订单 |
| `OrderDetailRoute` | `/commerce/orders/detail` | protectedShell/me | `$extra: OrderRef` | 已批准 | 权威重读订单；禁止外部打开 |
| `PaymentResultRoute` | `/commerce/payment` | protectedShell overlay | `$extra: PaymentIntentRef | PaymentAttemptRef` | 已批准 | 支付交接、确认与恢复；禁止结果参数 |
| `AssetLedgerRoute` | `/me/assets` | protectedShell/me | 无 | 已批准 | 当前会话本人 KingClub 资产，只读 |
| `SettingsRoute` | `/me/settings` | protectedShell/me | 无 | 已批准 | 固定 allowlist 设置入口 |
| `PaymentSecurityRoute` | `/me/settings/payment-security` | protectedShell/me | 无 | 已批准 | 支付 PIN 设置/修改/重置 |
| `AccountDeletionRoute` | `/me/settings/delete-account` | protectedShell/me | 无 | 已批准 | 仅 KingClub membership 注销 |
| `AboutLegalRoute` | `/me/settings/about` | protectedShell/me | 可选 `$extra: DocumentRef` | 已批准 | 关于目录或受控法律文档 |
| `PrivateStorageRoute` | `/me/storage` | protectedShell/me | 无 | In Review | 本人存酒和物品 |
| `StoragePickupCodeRoute` | `/me/storage/pickup` | protectedShell/me | `$extra: StorageItemRef` | In Review | 本人动态取件凭证 |

上述 Shell 目标当前只授权为导航决策语义；实现仍须等待对应页面与全局文档门禁。导航单元测试使用 fake target，不得因为出现在路由目录就创建占位页面代码。

48 页的语义名、主归属和准入状态见 [M0 路由语义库存](m0_route_inventory.md)。除本表首批全局目标外，其余页面在各自文档批准前不分配 location、不建立可执行 RouteIntent。

## 3. 仅内存参数

```text
AuthEntryContext
  exitPolicy              V1 固定 exitApp
  noticeCategory?         稳定通用提示，不含服务端原文

LoginFlowRef
  flowId                  安全随机、不透明、仅进程内索引
  generation              防止迟到导航引用旧流程

ConsentRouteContext
  mode                    readOnly | loginRecovery
  initialDocument?        terms | privacy，仅 readOnly
  loginFlowRef?           仅 loginRecovery 必需

SocialTargetRef
  refId                   不透明、仅进程内资源引用，不是 userAccount
  generation              会话世代
  expiresAt?              短期二维码预览必需

FriendRequestRef
  requestRefId            不透明、仅进程内申请引用
  generation              会话世代

ConversationRef
  refId                   不透明、仅进程内会话引用
  generation              会话世代

ShareIntentRef
  refId                   不透明、仅进程内分享引用
  generation              会话世代
  kind                    forward | businessCard
  expiresAt               强制过期时间

AaOfferRef
  refId                   不透明、仅进程内套餐引用
  generation              会话世代
  expiresAt               列表快照过期时间

AaQuoteRef
  refId                   不透明、仅进程内报价引用
  generation              会话世代
  quoteRevision           权威报价版本
  expiresAt               强制过期时间

ServiceDayRef
  refId                   不透明、仅进程内营业日引用
  generation              会话世代
  expiresAt               强制过期时间

PartyRef
  refId                   不透明、仅进程内组局引用，可在 Store 绑定邀请授权
  generation              会话世代

AdmissionRef
  refId                   不透明、仅进程内本人凭证引用
  generation              会话世代
  expiresAt?              来源上下文过期时间

ScanContextRef
  refId                   安全扫码解析后的受控上下文引用
  generation              会话世代
  kind                    admissionContext
  expiresAt               强制过期时间

OrderingContextRef
  refId                   安全扫码解析后的短时点单上下文
  generation              会话世代
  expiresAt               强制过期时间

QuoteRef
  refId                   服务端报价不透明引用
  generation              会话世代
  quoteRevision           报价版本
  expiresAt               强制过期时间

OrderRef
  refId                   当前用户订单的不透明引用
  generation              会话世代

PaymentIntentRef
  refId                   服务端支付意图不透明引用
  generation              会话世代
  expiresAt               强制过期时间

PaymentAttemptRef
  refId                   已创建支付尝试的不透明引用
  generation              会话世代

DocumentRef
  refId                   权威协议目录中的不透明文档引用
  generation              会话世代
  version                 明确文档版本

StorageItemRef
  refId                   本人储物的不透明引用
  generation              会话世代
```

- 这些对象通过类型化 `$extra` 传递，不生成 query/path，不注册 extra codec，不参与系统恢复。
- `flowId` 即使不含手机号也按敏感流程引用处理：禁止日志、埋点、截图附件和崩溃 breadcrumbs。
- RouteData 构造成功不代表上下文可信；页面构建前必须向 FlowStore 校验 generation、状态和所有权。

## 4. RouteIntent

业务层只能表达以下类型化意图，不能调用字符串 location：

```text
bootstrap
openMobileLogin(AuthEntryContext)
openSmsCode(LoginFlowRef)
openTermsReadOnly(document)
openTermsRecovery(LoginFlowRef)
openHome
selectPrimaryDestination(home | messages | discover | me)
openSafeScanner(OriginBranchRef)
openEditProfile
openPersonalQr
openContacts
openAddFriend
openFriendRequests
openUserProfile(SocialTargetRef, FriendRequestRef?)
openSendFriendRequest(SocialTargetRef)
openFriendRemark(SocialTargetRef)
openRelationshipPermissions(SocialTargetRef)
openBlacklist
openSystemNotifications
openDirectChat(ConversationRef)
openDirectChatDetails(ConversationRef)
openContactSelector(ShareIntentRef)
openAaReservations
openAaPackageDetail(AaOfferRef)
openAaOrderConfirmation(AaQuoteRef)
openVipPartyDetail(PartyRef?)
openVipPartyCreate(ServiceDayRef)
openVipPartyManagement(PartyRef)
openAdmissionTicket(AdmissionRef, ScanContextRef?)
openScanOrderingCart(OrderingContextRef)
openScanOrderConfirmation(QuoteRef)
openOrderCenter
openOrderDetail(OrderRef)
openPayment(PaymentIntentRef | PaymentAttemptRef)
openAssetLedger
openSettings
openPaymentSecurity
openAccountDeletion
openAboutLegal(DocumentRef?)
openPrivateStorage
openStoragePickupCode(StorageItemRef)
back
resetForSessionLoss(noticeCategory)
```

全部 48 页已批准，对应 RouteIntent 可在 Flutter UI/Mock 中实现。消息、AA、VIP Party、Admission、商业功能、ContentFeed、AssetLedger、设置与安全及私人储物柜 RouteIntent 均已完成文档准入。当前不得提前定义通用 future route；新增业务 RouteIntent 必须与对应功能/页面文档一起评审。

## 5. 导航动作语义

| 动作 | 用途 | 不变量 |
|---|---|---|
| `push` | 同一安全流程内临时查看并返回，例如协议 readOnly | 来源状态仍在内存且允许返回 |
| `pop(result)` | 返回已知来源 | 禁止依赖 pop 传递凭据或用户对象 |
| `replace` | mobile→code、code↔consentRecovery 等一次性步骤 | 被替换页面不得由系统返回恢复 |
| `reset` | 登录成功、注销、撤销、过期、账号不可用 | 原栈完全丢弃，只建立 home 或 mobile 安全根目标 |

页面发出 RouteIntent，由唯一 `NavigationCoordinator` 串行决策和执行。页面不得直接调用 `context.go('/...')`、拼接 URI 或持有全局 NavigatorKey。
