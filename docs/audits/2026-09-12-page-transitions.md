# 整页切换入口核对

用户要求全部整页右侧滑入、向右滑出；240ms/220ms。此前仅主题测试不足，补显式路由建页与所有Navigator整页入口禁用快照。弹窗/底部面板不是整页，保留各自交互。

## 显式补齐的声明路由
- AuthBootstrapRoute
- AppShellRoute
- ContentFeedRoute
- ContactsRoute
- AddFriendRoute
- FriendRequestsRoute
- UserProfileRoute
- SendFriendRequestRoute
- FriendRemarkRoute
- RelationshipPermissionsRoute
- BlacklistRoute
- SafeScannerRoute
- AaReservationsRoute
- AaPositioningCardRoute
- VipPartyRoute
- VipPartyCreateRoute
- VipPartyManagementRoute
- AdmissionTicketRoute
- ScanOrderingCartRoute
- ScanOrderConfirmationRoute
- OrderCenterRoute
- OrderDetailRoute
- PaymentResultRoute
- AssetLedgerRoute
- EditProfileRoute
- PaymentSecurityRoute
- AccountDeletionRoute
- AboutLegalRoute

## Navigator入口
- lib/src/app.dart: 1处
- lib/src/features/club/presentation/aa_order_confirmation_page.dart: 2处
- lib/src/features/club/presentation/aa_package_detail_page.dart: 1处
- lib/src/features/club/presentation/aa_reservations_page.dart: 1处
- lib/src/features/club/presentation/private_storage_page.dart: 2处
- lib/src/features/contacts/presentation/user_profile_page.dart: 3处
- lib/src/features/messaging/presentation/direct_chat_details_page.dart: 1处
- lib/src/features/messaging/presentation/direct_chat_page.dart: 2处
- lib/src/features/profile_settings/presentation/edit_profile_page.dart: 1处
- lib/src/features/profile_settings/presentation/my_profile_page.dart: 5处
- lib/src/features/profile_settings/presentation/settings_page.dart: 1处
- lib/src/features/scanner/presentation/member_scanner_page.dart: 1处
- lib/src/features/shell/presentation/app_shell_page.dart: 9处

系统相机、图库、权限页由系统控制；底栏栏目切换非整页导航。

## 验证

- flutter analyze 通过。
- 9 项针对性测试通过，包含生成的 GoRouter 路由：设置→关于与法律、返回、我的二维码进入及返回；断言动画进行中的水平位移及 240/220ms 时长。
- 其余路由完成代码入口核对，尚未逐页做真机动画验收。
- Preview profile APK 构建完成，ADB 覆盖安装 Success，冷启动 Status: ok（1703ms），未清除应用数据。
