# M0 48 页路由语义库存

- 文档状态：`In Review`
- 作用：保证每个冻结页面都有唯一导航语义和主归属；不是可直接实现的最终路由表。

## 规则

- `active`：已有批准页面文档，可进入最终 RouteData 设计。
- `global-review`：属于当前 App Shell/全局导航评审包，用户批准后才可激活。
- `reserved`：只保留语义名；对应页面文档批准前不得分配最终 location、参数或实现 RouteIntent。
- 所有 protected 页面默认禁止外部打开；以后启用 App Link/推送必须逐页变更本表。

| Scope ID | RouteData 语义名 | 分区/主归属 | 状态 |
|---|---|---|---|
| KC-P-001 | AuthBootstrapRoute | bootstrap | active |
| KC-P-002 | MobileLoginRoute | authFlow | active |
| KC-P-003 | SmsCodeRoute | authFlow | active |
| KC-P-004 | TermsConsentRoute | authFlow | active |
| KC-P-005 | RealNameAdultVerificationRoute | onboarding | reserved |
| KC-P-006 | MembershipImageSubmissionRoute | onboarding | reserved |
| KC-P-007 | StyleMusicPreferencesRoute | onboarding | reserved |
| KC-P-008 | DrinkEventPreferencesRoute | onboarding | reserved |
| KC-P-009 | MembershipReviewStatusRoute | onboarding/review | reserved |
| KC-P-010 | AppShellRoute | protectedShell container | global-review |
| KC-P-011 | HomeRoute | protectedShell/home | global-review |
| KC-P-012 | SafeScannerRoute | protectedShell overlay | global-review |
| KC-P-013 | ContentFeedRoute | protectedShell/discover | global-review |
| KC-P-014 | ContactsRoute | protectedShell/messages | reserved |
| KC-P-015 | AddFriendRoute | protectedShell/messages | reserved |
| KC-P-016 | FriendRequestsRoute | protectedShell/messages | reserved |
| KC-P-017 | UserProfileRoute | protectedShell/messages | reserved |
| KC-P-018 | SendFriendRequestRoute | protectedShell/messages | reserved |
| KC-P-019 | FriendRemarkRoute | protectedShell/messages | reserved |
| KC-P-020 | RelationshipPermissionsRoute | protectedShell/messages | reserved |
| KC-P-021 | BlacklistRoute | protectedShell/messages | reserved |
| KC-P-022 | ConversationsRoute | protectedShell/messages | global-review |
| KC-P-023 | SystemNotificationsRoute | protectedShell/messages | reserved |
| KC-P-024 | DirectChatRoute | protectedShell/messages | reserved |
| KC-P-025 | DirectChatDetailsRoute | protectedShell/messages | reserved |
| KC-P-026 | ContactSelectorRoute | protectedShell/messages overlay | reserved |
| KC-P-027 | AaReservationsRoute | protectedShell/home | reserved |
| KC-P-028 | AaPackageDetailRoute | protectedShell/home | reserved |
| KC-P-029 | AaOrderConfirmationRoute | protectedShell/home | reserved |
| KC-P-030 | VipPartyDetailRoute | protectedShell/home | reserved |
| KC-P-031 | VipPartyCreateRoute | protectedShell/home | reserved |
| KC-P-032 | VipPartyManagementRoute | protectedShell/home | reserved |
| KC-P-033 | AdmissionTicketRoute | protectedShell/home | reserved |
| KC-P-034 | ScanOrderingCartRoute | protectedShell overlay/home | reserved |
| KC-P-035 | ScanOrderConfirmationRoute | protectedShell overlay/home | reserved |
| KC-P-036 | OrderCenterRoute | protectedShell/me | reserved |
| KC-P-037 | OrderDetailRoute | protectedShell/me | reserved |
| KC-P-038 | PaymentResultRoute | protectedShell overlay | reserved |
| KC-P-039 | AssetLedgerRoute | protectedShell/me | reserved |
| KC-P-040 | MyProfileRoute | protectedShell/me | global-review |
| KC-P-041 | EditProfileRoute | protectedShell/me | reserved |
| KC-P-042 | PersonalQrRoute | protectedShell/me | reserved |
| KC-P-043 | SettingsRoute | protectedShell/me | reserved |
| KC-P-044 | PaymentSecurityRoute | protectedShell/me | reserved |
| KC-P-045 | AccountDeletionRoute | protectedShell/me | reserved |
| KC-P-046 | AboutLegalRoute | protectedShell/me | reserved |
| KC-P-047 | PrivateStorageRoute | protectedShell/me | reserved |
| KC-P-048 | StoragePickupCodeRoute | protectedShell/me | reserved |

## 参数与对象权限

- 用户、会话、验证码、Token、支付结果和完整业务对象不得进入 URI。
- 未来资源参数只接受页面文档批准的不透明 ID/枚举；格式校验不替代服务端对象级权限。
- 联系人选择、支付结果、扫码来源等临时上下文优先使用受控内存引用；是否允许恢复由页面逐项决定。
- 页面从 `reserved` 变更为 active 时，必须同时更新页面文档、route catalog、守卫、返回、测试和覆盖账本。
