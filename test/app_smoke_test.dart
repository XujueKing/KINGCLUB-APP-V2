import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/app.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/core/mock/mock_runtime.dart';
import 'package:kingclub/src/features/auth/presentation/auth_bootstrap_page.dart';
import 'package:kingclub/src/features/auth/presentation/terms_consent_page.dart';
import 'package:kingclub/src/features/club/presentation/private_storage_page.dart';
import 'package:kingclub/src/features/club/presentation/storage_pickup_code_page.dart';
import 'package:kingclub/src/features/content/presentation/content_feed_page.dart';
import 'package:kingclub/src/features/contacts/presentation/contacts_page.dart';
import 'package:kingclub/src/features/contacts/presentation/blacklist_page.dart';
import 'package:kingclub/src/features/contacts/presentation/friendship_pages.dart';
import 'package:kingclub/src/features/contacts/presentation/friend_remark_page.dart';
import 'package:kingclub/src/features/contacts/presentation/relationship_permissions_page.dart';
import 'package:kingclub/src/features/contacts/presentation/send_friend_request_page.dart';
import 'package:kingclub/src/features/contacts/presentation/user_profile_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/about_legal_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/account_deletion_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/edit_profile_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/payment_security_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/personal_qr_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/settings_page.dart';
import 'package:kingclub/src/features/messaging/presentation/contact_selector_page.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_details_page.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';
import 'package:kingclub/src/features/messaging/presentation/system_notifications_page.dart';
import 'package:kingclub/src/features/scanner/presentation/safe_scanner_page.dart';
import 'package:kingclub/src/features/shell/presentation/app_shell_page.dart';

void main() {
  testWidgets('auth bootstrap error uses production facing copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapOutcomeProvider.overrideWith(
            (ref) => Future<BootstrapOutcome>.error(Exception('offline')),
          ),
        ],
        child: MaterialApp(
          home: AuthBootstrapPage(onAnonymous: () {}, onAuthenticated: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂时无法启动'), findsOneWidget);
    expect(find.text('请检查网络连接后重试。'), findsOneWidget);
    expect(find.textContaining('Mock'), findsNothing);
    expect(find.textContaining('真实服务'), findsNothing);
  });

  testWidgets('terms page keeps technical placeholder labels out of UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TermsConsentPage(
          initialAgreement: AgreementKind.terms,
          onClose: () {},
        ),
      ),
    );

    expect(find.text('用户协议'), findsOneWidget);
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.textContaining('Mock'), findsNothing);
    expect(find.textContaining('测试模式'), findsNothing);
    expect(find.text('协议正文以正式发布版本为准。'), findsOneWidget);

    await tester.tap(find.text('隐私政策'));
    await tester.pumpAndSettle();
    expect(find.textContaining('KingClub 隐私政策'), findsOneWidget);
  });

  testWidgets('anonymous bootstrap opens legacy welcome then login', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KingClubApp()));
    expect(find.text('正在安全检查登录状态'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('legacy-welcome-background')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('legacy-welcome-logo')), findsOneWidget);
    expect(find.text('BUSINESS HOURS'), findsOneWidget);
    expect(find.text('20:30-04:00'), findsOneWidget);
    expect(find.text('Mobile Phone:'), findsNothing);
    final welcomeNext = tester.widget<FilledButton>(
      find.byKey(const ValueKey('legacy-welcome-next')),
    );
    expect(welcomeNext.onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('legacy-welcome-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('legacy-welcome-next')));
    await tester.pumpAndSettle();

    expect(find.text('Mobile Phone:'), findsOneWidget);
    expect(find.text('Code:'), findsOneWidget);
    expect(find.text('获取验证码'), findsOneWidget);
    expect(find.text('SHANGHAI . ZHUZHOU'), findsOneWidget);
    final loginLogo = find.byKey(const ValueKey('mobile-login-brand-logo'));
    expect(loginLogo, findsOneWidget);
    expect(
      tester.getCenter(loginLogo).dx,
      moreOrLessEquals(tester.getCenter(find.byType(Scaffold)).dx, epsilon: 1),
    );
    final loginContent = find.byKey(const ValueKey('mobile-login-content'));
    expect(loginContent, findsOneWidget);
    expect(
      tester.getCenter(loginContent).dx,
      moreOrLessEquals(tester.getCenter(find.byType(Scaffold)).dx, epsilon: 1),
    );
    expect(find.text('UI 测试说明'), findsNothing);
    expect(find.text('我已阅读并同意'), findsNothing);
  });

  testWidgets('system back never empties the auth onboarding router', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KingClubApp()));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('legacy-welcome-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('legacy-welcome-next')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('mobile-login-phone-field')),
        matching: find.byType(EditableText),
      ),
      '13800000003',
    );
    await tester.tap(find.text('获取验证码'));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('mobile-login-code-field')),
        matching: find.byType(EditableText),
      ),
      '888888',
    );
    await tester.pump();
    final mobileNext = find.byKey(const ValueKey('mobile-login-next'));
    await tester.ensureVisible(mobileNext);
    await tester.pumpAndSettle();
    await tester.tap(mobileNext);
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pumpAndSettle();
    expect(find.text('步骤 1/4'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Mobile Phone:'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('legacy-welcome-background')),
      findsOneWidget,
    );
    expect(find.byType(Scaffold), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('legacy-welcome-background')),
      findsOneWidget,
    );
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('mock sms and onboarding flow reaches the app shell', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KingClubApp()));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('legacy-welcome-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('legacy-welcome-next')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('mobile-login-phone-field')),
        matching: find.byType(EditableText),
      ),
      '13800000000',
    );
    await tester.tap(find.text('获取验证码'));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();
    final codeField = find.descendant(
      of: find.byKey(const ValueKey('mobile-login-code-field')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(codeField).decoration?.hintText, '输入验证码');
    await tester.tap(codeField);
    await tester.pump();
    expect(tester.widget<TextField>(codeField).decoration?.hintText, isNull);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('mobile-login-code-field')),
        matching: find.byType(EditableText),
      ),
      '888888',
    );
    await tester.pump();
    final mobileNext = find.byKey(const ValueKey('mobile-login-next'));
    await tester.ensureVisible(mobileNext);
    await tester.pumpAndSettle();
    await tester.tap(mobileNext);
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pumpAndSettle();

    expect(find.text('步骤 1/4'), findsOneWidget);
    expect(find.text('未满18岁未成年人\n不得饮酒注册会员'), findsOneWidget);
    expect(find.text('姓名'), findsNothing);
    expect(find.text('证件号码'), findsNothing);
    expect(find.text('NAME:'), findsOneWidget);
    expect(find.text('ID CARD:'), findsOneWidget);
    final nameFieldSize = tester.getSize(
      find.byKey(const ValueKey('real-name-name-field')),
    );
    expect(nameFieldSize.width, moreOrLessEquals(420, epsilon: 1));
    expect(nameFieldSize.height, moreOrLessEquals(52, epsilon: 1));
    expect(
      tester.getCenter(find.text('NAME:')).dx,
      moreOrLessEquals(
        tester.getCenter(find.byKey(const ValueKey('real-name-name-field'))).dx,
        epsilon: 1,
      ),
    );
    expect(
      tester.getCenter(find.text('ID CARD:')).dx,
      moreOrLessEquals(
        tester.getCenter(find.byKey(const ValueKey('real-name-id-field'))).dx,
        epsilon: 1,
      ),
    );
    expect(find.text('合成数据演示'), findsNothing);
    expect(find.textContaining('中华人民共和国未成年人保护法'), findsNothing);
    expect(find.textContaining('我已阅读并同意：本人已满18周岁'), findsOneWidget);

    final idField = find.byKey(const ValueKey('real-name-id-field'));
    expect(tester.widget<TextField>(idField).decoration?.hintText, '请输入证件号码');
    await tester.tap(idField);
    await tester.pump();
    expect(tester.widget<TextField>(idField).decoration?.hintText, isEmpty);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('real-name-name-field')),
        matching: find.byType(EditableText),
      ),
      '测试会员',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('real-name-id-field')),
        matching: find.byType(EditableText),
      ),
      '430102199001011234',
    );
    expect(find.text('开始 Fake 核验'), findsNothing);
    final verifyButton = find.byKey(const ValueKey('real-name-verify-button'));
    final identityTextField = find.byKey(const ValueKey('real-name-id-field'));
    expect(tester.widget<TextField>(identityTextField).obscureText, isFalse);
    expect(find.byKey(const ValueKey('real-name-id-visibility')), findsNothing);
    final adultConsent = find.byKey(
      const ValueKey('real-name-notice-checkbox'),
    );
    expect(adultConsent, findsOneWidget);
    expect(tester.widget<FilledButton>(verifyButton).onPressed, isNotNull);
    await tester.tap(adultConsent);
    await tester.pump();
    await tester.ensureVisible(verifyButton);
    await tester.tap(verifyButton);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('完善会员形象资料'), findsOneWidget);
    expect(find.text('请添加两张近期清晰照片，仅用于会员审核。'), findsOneWidget);
    expect(find.textContaining('Mock'), findsNothing);
    expect(find.textContaining('合成示例'), findsNothing);
    await tester.tap(find.text('点击添加').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('从相册选择'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('点击添加').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('从相册选择'));
    await tester.pumpAndSettle();
    expect(find.text('已添加'), findsNWidgets(2));
    await tester.tap(find.text('下一步'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('你的风格偏好'), findsOneWidget);
    await tester.ensureVisible(find.text('暂时跳过'));
    await tester.tap(find.text('暂时跳过'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('完善兴趣偏好'), findsOneWidget);
    expect(find.text('提交后将进入会员审核流程，最终结果请以审核状态页显示为准。'), findsOneWidget);
    expect(find.textContaining('Mock 只模拟'), findsNothing);
    final drinkNotice = find.byKey(const ValueKey('drink-event-review-notice'));
    await tester.ensureVisible(find.text('跳过偏好并提交'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(drinkNotice).dy,
      greaterThan(tester.getBottomLeft(find.text('跳过偏好并提交')).dy),
    );
    await tester.tap(find.text('跳过偏好并提交'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('会员申请审核中'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('membership-review-brand-logo')),
      findsNothing,
    );
    final reviewContent = find.byKey(
      const ValueKey('membership-review-content'),
    );
    expect(reviewContent, findsOneWidget);
    expect(
      tester.getCenter(reviewContent).dx,
      moreOrLessEquals(tester.getCenter(find.byType(Scaffold)).dx, epsilon: 1),
    );
    expect(find.text('KINGCLUB'), findsNothing);
    await tester.ensureVisible(find.text('UI 测试场景'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('UI 测试场景')).dy,
      greaterThan(tester.getBottomLeft(find.text('退出登录')).dy),
    );
    await tester.tap(find.text('UI 测试场景'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('已通过'));
    await tester.tap(find.text('已通过'));
    await tester.pump();
    await tester.ensureVisible(find.text('进入 KingClub'));
    expect(find.text('刷新状态'), findsNothing);
    expect(find.text('退出登录'), findsNothing);
    await tester.tap(find.text('进入 KingClub'));
    await tester.pumpAndSettle();

    expect(find.text('青铜'), findsOneWidget);
    expect(find.text('L-0 EXP:50'), findsOneWidget);
    expect(find.text('一起玩'), findsOneWidget);
    expect(find.text('组局玩'), findsOneWidget);
    expect(find.text('SCAN QR'), findsOneWidget);
    expect(find.bySemanticsLabel('首页，标签，已选中'), findsOneWidget);
    expect(find.bySemanticsLabel('消息，标签，5 条未读'), findsOneWidget);
    expect(find.bySemanticsLabel('内容，标签'), findsOneWidget);
    expect(find.bySemanticsLabel('私人储物柜，标签'), findsOneWidget);
    expect(find.bySemanticsLabel('我的，标签'), findsOneWidget);

    // The legacy 140rpx action row can sit behind the floating bottom bar in
    // Flutter's short default test viewport. Scroll it into the unobscured
    // area and target the card itself instead of a text glyph.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-quick-together')));
    await tester.pumpAndSettle();
    expect(find.text('一起玩AA预定'), findsOneWidget);
    expect(find.text('一键随机选座'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-quick-party')));
    await tester.pumpAndSettle();
    expect(find.text('VIP组局'), findsOneWidget);
    expect(find.text('预定一个新卡座'), findsOneWidget);
  });

  testWidgets('mock sms rate limit stays on mobile login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KingClubApp()));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('legacy-welcome-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('legacy-welcome-next')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('mobile-login-phone-field')),
        matching: find.byType(EditableText),
      ),
      '13800000001',
    );
    await tester.tap(find.text('获取验证码'));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(find.text('请求过于频繁，请 60 秒后重试'), findsOneWidget);
    expect(find.text('手机号登录'), findsNothing);
  });

  testWidgets('safe scanner emits only an approved fake route intent', (
    tester,
  ) async {
    SafeScanDestination? resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: SafeScannerPage(
          onClose: () {},
          onResolved: (value) => resolved = value,
        ),
      ),
    );

    expect(find.text('只识别 KingClub 可信场景'), findsOneWidget);
    await tester.ensureVisible(find.text('开始扫码'));
    await tester.tap(find.text('开始扫码'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('将二维码放入框内'), findsOneWidget);
    await tester.ensureVisible(find.text('展开 UI 测试场景'));
    await tester.tap(find.text('展开 UI 测试场景'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('好友资料'));
    await tester.tap(find.text('好友资料'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('识别成功'), findsOneWidget);
    await tester.ensureVisible(find.text('进入好友资料预览'));
    await tester.tap(find.text('进入好友资料预览'));
    expect(resolved, SafeScanDestination.friendProfile);
  });

  testWidgets('content feed is read only, muted and vertically browsable', (
    tester,
  ) async {
    String? authorRef;
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: Scaffold(
          body: ContentFeedPage(
            active: true,
            onOpenAuthor: (value) => authorRef = value,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('NEON 阿澈'), findsOneWidget);
    expect(find.text('静音'), findsNothing);
    expect(
      find.byKey(const ValueKey('content-feed-audio-toggle')),
      findsOneWidget,
    );
    expect(find.text('发布'), findsNothing);
    expect(find.text('点赞'), findsNothing);
    expect(find.text('评论'), findsNothing);

    await tester.tap(find.text('NEON 阿澈'));
    expect(authorRef, 'social-target-neon');

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('周末组局官'), findsOneWidget);
  });

  testWidgets('contacts searches only fake friend names and emits intent', (
    tester,
  ) async {
    ContactRouteIntent? intent;
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: Scaffold(
          body: ContactsPage(active: true, onIntent: (value) => intent = value),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('新的朋友'), findsOneWidget);
    expect(find.text('添加好友'), findsOneWidget);
    expect(find.text('黑名单'), findsOneWidget);
    expect(find.text('卡座搭子'), findsOneWidget);
    expect(find.textContaining('手机号'), findsNothing);
    expect(find.text('仅 KingClub 好友'), findsNothing);
    expect(find.byTooltip('UI 测试场景'), findsNothing);
    expect(find.byTooltip('更多'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('contacts-blacklist')));
    expect(intent?.kind, ContactIntentKind.blacklist);

    await tester.tap(find.byTooltip('添加好友'));
    expect(intent?.kind, ContactIntentKind.addFriend);

    await tester.enterText(find.byType(TextField), '卡座搭子');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('卡座搭子'), findsNWidgets(2));
    expect(find.text('艾琳'), findsNothing);

    await tester.tap(find.text('卡座搭子').last);
    expect(intent?.kind, ContactIntentKind.userProfile);
    expect(intent?.targetRef, 'contact-lucas');
  });

  testWidgets('legacy user profile shows safe fake friend actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: const UserProfilePage(targetRef: 'contact-lucas'),
      ),
    );

    expect(find.text('卡座搭子'), findsOneWidget);
    expect(find.text('昵称：Lucas'), findsOneWidget);
    expect(find.text('朋友资料'), findsOneWidget);
    expect(find.text('朋友权限'), findsOneWidget);
    expect(find.text('发消息'), findsOneWidget);
    expect(find.textContaining('会员号'), findsNothing);
    expect(find.textContaining('手机号'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('user-profile-details')));
    await tester.pumpAndSettle();
    expect(find.text('朋友资料'), findsOneWidget);
    expect(find.text('备注名'), findsOneWidget);
    expect(find.text('说明'), findsOneWidget);
    expect(find.text('来自 扫一扫'), findsOneWidget);
    expect(find.textContaining('电话'), findsNothing);
  });

  testWidgets('friend remark reproduces legacy edit dialog locally', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: const FriendRemarkPage(
          targetRef: 'contact-lucas',
          initialRemark: '卡座搭子',
          signature: '周末一起听现场',
        ),
      ),
    );

    expect(find.text('更多信息'), findsOneWidget);
    expect(find.text('2026-08-25'), findsOneWidget);
    expect(find.textContaining('电话'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('friend-remark-name')));
    await tester.pumpAndSettle();
    expect(find.text('修改备注名'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('friend-remark-input-备注名')),
      '现场搭子',
    );
    await tester.tap(find.byKey(const ValueKey('friend-remark-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('现场搭子'), findsOneWidget);
  });

  testWidgets('relationship permissions requires destructive confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: const RelationshipPermissionsPage(
          targetRef: 'contact-lucas',
          displayName: '卡座搭子',
        ),
      ),
    );

    expect(find.text('权限'), findsOneWidget);
    expect(find.text('聊天、朋友圈、交友等'), findsOneWidget);
    expect(find.text('仅聊天'), findsOneWidget);
    expect(find.text('加入黑名单'), findsOneWidget);
    expect(find.text('删除联系人'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('relationship-messages-only')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('relationship-block')));
    await tester.pumpAndSettle();
    expect(find.textContaining('解除后不会自动恢复好友'), findsOneWidget);
    expect(find.text('确认拉黑'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('relationship-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('不会加入黑名单'), findsOneWidget);
    expect(find.text('确认删除'), findsOneWidget);
  });

  testWidgets('blacklist reproduces legacy fake list and unblock flow', (
    tester,
  ) async {
    String? openedTarget;
    var addOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: BlacklistPage(
          onOpenAddFriend: () => addOpened = true,
          onOpenUserProfile: (targetRef) => openedTarget = targetRef,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('黑名单'), findsOneWidget);
    expect(find.text('艾琳'), findsOneWidget);
    expect(find.text('阿浩'), findsOneWidget);
    expect(find.text('墨墨'), findsOneWidget);
    expect(find.textContaining('手机号'), findsNothing);
    expect(find.textContaining('会员号'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('blacklist-contact-alice')));
    expect(openedTarget, 'contact-alice');

    await tester.tap(find.byKey(const ValueKey('blacklist-add-friend')));
    expect(addOpened, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('blacklist-switch-contact-alice')),
    );
    await tester.pumpAndSettle();
    expect(find.text('解除黑名单'), findsOneWidget);
    expect(find.textContaining('不会自动恢复好友'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('blacklist-confirm-unblock')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('艾琳'), findsNothing);
    expect(find.text('阿浩'), findsOneWidget);
  });

  testWidgets('stranger profile request updates to waiting locally', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: const UserProfilePage(
          targetRef: 'contact-alice',
          initialRelationship: UserProfileRelationship.stranger,
        ),
      ),
    );

    expect(find.text('来自 扫一扫'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('user-profile-add')));
    await tester.pumpAndSettle();

    expect(find.text('申请添加朋友'), findsOneWidget);
    expect(find.text('发送添加朋友申请'), findsOneWidget);
    expect(find.text('设置备注名'), findsOneWidget);
    final messageField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('send-friend-message')),
        matching: find.byType(TextField),
      ),
    );
    final remarkField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('send-friend-remark')),
        matching: find.byType(TextField),
      ),
    );
    expect(messageField.controller?.text, '我是 KingClub 会员');
    expect(remarkField.controller?.text, '艾琳');
    expect(find.textContaining('手机号'), findsNothing);
    expect(find.textContaining('会员号'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('send-friend-submit')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('等待对方验证'), findsOneWidget);
  });

  testWidgets('send friend request protects a changed fake draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: const SendFriendRequestPage(
          targetRef: 'contact-alice',
          targetName: '艾琳',
        ),
      ),
    );

    expect(find.text('申请添加朋友'), findsOneWidget);
    expect(find.byKey(const ValueKey('send-friend-message')), findsOneWidget);
    expect(find.byKey(const ValueKey('send-friend-remark')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('send-friend-message')),
      '你好，一起去 KingClub 吧',
    );
    await tester.tap(find.byKey(const ValueKey('send-friend-back')));
    await tester.pumpAndSettle();

    expect(find.text('放弃本次申请？'), findsOneWidget);
    expect(find.text('继续编辑'), findsOneWidget);
    expect(find.text('放弃'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('申请添加朋友'), findsOneWidget);
  });

  testWidgets('message branch keeps contacts and opens legacy chat list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AppShellPage(
          initialIndex: 1,
          onOpenScanner: (_, _) async => null,
          onOpenTogether: () {},
          onOpenParty: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('新的朋友'), findsOneWidget);
    expect(find.text('添加好友'), findsOneWidget);

    await tester.tap(find.text('聊天'));
    await tester.pumpAndSettle();

    expect(find.text('折叠置顶聊天'), findsOneWidget);
    expect(find.text('KING CLUB'), findsOneWidget);
    expect(find.text('收到50枚金币'), findsOneWidget);
    expect(find.text('08月23日'), findsOneWidget);
    expect(find.bySemanticsLabel('消息，标签，5 条未读，已选中'), findsOneWidget);

    await tester.tap(find.text('通讯录'));
    await tester.pumpAndSettle();
    expect(find.text('新的朋友'), findsOneWidget);
  });

  testWidgets('conversation list manages unread pin and delete locally', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AppShellPage(
          initialIndex: 1,
          onOpenScanner: (_, _) async => null,
          onOpenTogether: () {},
          onOpenParty: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('conversation-unread-badge')),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);

    await tester.longPress(
      find.byKey(const ValueKey('conversation-seatmate-row')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('conversation-menu-read')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('conversation-unread-badge')),
      findsNothing,
    );

    await tester.longPress(
      find.byKey(const ValueKey('conversation-seatmate-row')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('conversation-menu-pin')));
    await tester.pumpAndSettle();
    expect(find.text('已置顶'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('conversation-pinned-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('2 个置顶聊天'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('conversation-seatmate-row')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('conversation-pinned-toggle')));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('conversation-seatmate-row')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('conversation-swipe-delete')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('conversation-swipe-delete')));
    await tester.pumpAndSettle();
    expect(find.text('确认删除并清空记录？\n当前为本地 UI Mock，不会影响服务器数据。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('conversation-confirm-delete')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('conversation-seatmate-row')),
      findsNothing,
    );
    expect(find.text('KING CLUB'), findsOneWidget);
    expect(find.text('暂无会话'), findsNothing);
  });

  testWidgets('conversation refresh keeps cached rows and recovers locally', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AppShellPage(
          initialIndex: 1,
          onOpenScanner: (_, _) async => null,
          onOpenTogether: () {},
          onOpenParty: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天'));
    await tester.pumpAndSettle();

    final refreshFinder = find.descendant(
      of: find.byType(ConversationsPage),
      matching: find.byType(RefreshIndicator),
    );
    final refresh = tester.widget<RefreshIndicator>(refreshFinder);
    final refreshFuture = refresh.onRefresh();
    await tester.pump(const Duration(milliseconds: 500));
    await refreshFuture;
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('conversation-offline-banner')),
      findsOneWidget,
    );
    expect(find.text('网络不可用，已保留最近会话'), findsOneWidget);
    expect(find.text('缓存更新于 今天 21:08'), findsOneWidget);
    expect(find.text('KING CLUB'), findsOneWidget);
    expect(find.text('卡座搭子'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('conversation-refresh-retry')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('conversation-offline-banner')),
      findsNothing,
    );
    expect(find.text('会话已是最新（UI Mock）'), findsOneWidget);
  });

  testWidgets('relationship ended conversation becomes a read only summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AppShellPage(
          initialIndex: 1,
          onOpenScanner: (_, _) async => null,
          onOpenTogether: () {},
          onOpenParty: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天'));
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey('conversation-seatmate-row')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('conversation-menu-relationship-ended')),
    );
    await tester.pumpAndSettle();

    expect(find.text('好友关系已结束 · 仅可查看历史摘要'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('conversation-unread-badge')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('conversation-seatmate-row')));
    await tester.pumpAndSettle();
    expect(find.text('好友关系已结束'), findsOneWidget);
    expect(find.text('该会话仅保留本地历史摘要，不能继续发送消息。'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('conversation-readonly-dismiss')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DirectChatPage), findsNothing);
  });

  testWidgets('invalid conversation ignores a stale local recovery', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AppShellPage(
          initialIndex: 1,
          onOpenScanner: (_, _) async => null,
          onOpenTogether: () {},
          onOpenParty: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天'));
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey('conversation-seatmate-row')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('conversation-menu-invalid')));
    await tester.pumpAndSettle();
    expect(find.text('会话已失效 · 请本地刷新'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('conversation-seatmate-row')));
    await tester.pumpAndSettle();
    expect(find.text('会话已失效'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('conversation-invalid-refresh')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.longPress(
      find.byKey(const ValueKey('conversation-seatmate-row')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('conversation-menu-relationship-ended')),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('好友关系已结束 · 仅可查看历史摘要'), findsOneWidget);
    expect(find.text('周末 KING CLUB 见？'), findsNothing);
  });

  testWidgets('system notifications expands and marks fake notices read', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const SystemNotificationsPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('系统消息'), findsOneWidget);
    expect(find.text('签到获得'), findsOneWidget);
    await tester.tap(find.text('签到获得'));
    await tester.pumpAndSettle();
    expect(find.text('株洲 KINGCLUB 清吧'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('system-notifications-read-all')),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('system unread count stays linked to the conversation row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AppShellPage(
          initialIndex: 1,
          onOpenScanner: (_, _) async => null,
          onOpenTogether: () {},
          onOpenParty: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天'));
    await tester.pumpAndSettle();

    final systemBadge = find.byKey(
      const ValueKey('system-conversation-unread-badge'),
    );
    expect(systemBadge, findsOneWidget);
    expect(
      find.descendant(of: systemBadge, matching: find.text('3')),
      findsOneWidget,
    );

    await tester.tap(find.text('KING CLUB'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('签到获得'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('messaging-back')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: systemBadge, matching: find.text('2')),
      findsOneWidget,
    );

    await tester.tap(find.text('KING CLUB'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('system-notifications-read-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('messaging-back')));
    await tester.pumpAndSettle();
    expect(systemBadge, findsNothing);
  });

  testWidgets('shell message badge aggregates system and friend unread', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AppShellPage(
          initialIndex: 1,
          onOpenScanner: (_, _) async => null,
          onOpenTogether: () {},
          onOpenParty: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shellBadge = find.byKey(const ValueKey('shell-message-unread-badge'));
    expect(
      find.descendant(of: shellBadge, matching: find.text('5')),
      findsOneWidget,
    );

    await tester.tap(find.text('聊天'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: shellBadge, matching: find.text('5')),
      findsOneWidget,
    );

    await tester.tap(find.text('KING CLUB'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('签到获得'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('messaging-back')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: shellBadge, matching: find.text('4')),
      findsOneWidget,
    );

    await tester.tap(find.text('KING CLUB'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('system-notifications-read-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('messaging-back')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: shellBadge, matching: find.text('2')),
      findsOneWidget,
    );

    await tester.tap(find.text('卡座搭子'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('messaging-back')));
    await tester.pumpAndSettle();
    expect(shellBadge, findsNothing);
    expect(find.bySemanticsLabel('消息，标签，已选中'), findsOneWidget);
  });

  testWidgets('shell message badge hides zero and caps overflow at 99 plus', (
    tester,
  ) async {
    Widget shell({required int systemUnread, required int friendUnread}) {
      return MaterialApp(
        theme: KingTheme.dark,
        home: AppShellPage(
          key: ValueKey('$systemUnread-$friendUnread'),
          initialSystemUnreadCount: systemUnread,
          initialFriendUnreadCount: friendUnread,
          onOpenScanner: (_, _) async => null,
          onOpenTogether: () {},
          onOpenParty: () {},
        ),
      );
    }

    await tester.pumpWidget(shell(systemUnread: 100, friendUnread: 20));
    await tester.pumpAndSettle();
    final shellBadge = find.byKey(const ValueKey('shell-message-unread-badge'));
    expect(
      find.descendant(of: shellBadge, matching: find.text('99+')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('消息，标签，99 条以上未读'), findsOneWidget);

    await tester.pumpWidget(shell(systemUnread: 0, friendUnread: 0));
    await tester.pumpAndSettle();
    expect(shellBadge, findsNothing);
    expect(find.bySemanticsLabel('消息，标签'), findsOneWidget);
  });

  testWidgets('direct chat sends and retries local fake messages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('卡座搭子'), findsOneWidget);
    final messageList = tester.widget<ListView>(
      find.byKey(const ValueKey('direct-chat-message-list')),
    );
    expect(
      messageList.keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
    expect(messageList.scrollCacheExtent?.value, 640);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('direct-chat-input')))
          .textInputAction,
      TextInputAction.send,
    );
    final chatInput = tester.widget<TextField>(
      find.byKey(const ValueKey('direct-chat-input')),
    );
    expect(
      (chatInput.decoration?.focusedBorder as OutlineInputBorder).borderSide,
      BorderSide.none,
    );
    expect(find.text('你已添加了卡座搭子，现在可以开始聊天了。'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('你已添加了卡座搭子，现在可以开始聊天了。')).dy,
      lessThan(tester.getTopLeft(find.text('周末 KING CLUB 见？')).dy),
    );
    await tester.enterText(
      find.byKey(const ValueKey('direct-chat-input')),
      '失败',
    );
    await tester.pump();
    final enabledSend = tester.widget<TextButton>(
      find.byKey(const ValueKey('direct-chat-send')),
    );
    expect(
      enabledSend.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xFF07C160),
    );
    await tester.tap(find.byKey(const ValueKey('direct-chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('发送失败，重试'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('direct-chat-retry')));
    await tester.pumpAndSettle();
    expect(find.text('发送失败，重试'), findsNothing);
  });

  testWidgets('direct chat media attachment opens a local preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()),
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('direct-chat-input'));
    final attachments = find.byKey(const ValueKey('direct-chat-attachments'));
    await tester.tap(attachments);
    await tester.pumpAndSettle();
    expect(find.text('照片'), findsOneWidget);
    await tester.tap(input);
    await tester.pump();
    expect(find.text('照片'), findsNothing);
    await tester.tap(attachments);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).focusNode?.hasFocus, isFalse);
    await tester.tap(find.text('照片'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('direct-chat-image-message')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('direct-chat-image-message')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('direct-chat-media-preview')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('direct-chat-close-media')));
    await tester.pumpAndSettle();
  });

  testWidgets('direct chat restores legacy extensions and gift mock', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('direct-chat-attachments')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('direct-chat-attachment-panel')),
      findsOneWidget,
    );
    expect(find.text('照片'), findsOneWidget);
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('金币'), findsOneWidget);
    expect(find.text('红包'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('direct-chat-gifts')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('direct-chat-attachment-panel')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('direct-chat-gift-panel')),
      findsOneWidget,
    );
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('场景特效'), findsOneWidget);
    expect(find.text('爱意表达'), findsOneWidget);
    expect(find.text('装饰互动'), findsOneWidget);
    expect(find.text('501'), findsOneWidget);

    final affordableGift = find.byKey(const ValueKey('direct-chat-gift-5'));
    await tester.ensureVisible(affordableGift);
    await tester.pumpAndSettle();
    await tester.tap(affordableGift);
    await tester.pump();
    final giftSend = find.byKey(const ValueKey('direct-chat-gift-send-5'));
    await tester.ensureVisible(giftSend);
    await tester.tap(giftSend);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('direct-chat-gift-message')),
      findsOneWidget,
    );
    expect(find.text('天鹅之梦'), findsOneWidget);
  });

  testWidgets('direct chat keeps long and burst messages stable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()),
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('direct-chat-input'));
    final send = find.byKey(const ValueKey('direct-chat-send'));
    final longText = List<String>.filled(180, '长').join();

    await tester.enterText(input, longText);
    await tester.pump();
    final inputHeight = tester.getSize(input).height;
    expect(inputHeight, greaterThan(48));
    expect(inputHeight, lessThanOrEqualTo(132));
    expect(tester.widget<TextField>(input).maxLines, 4);
    await tester.tap(send);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(longText), findsOneWidget);
    expect(tester.getSize(find.text(longText)).width, lessThanOrEqualTo(252));
    expect(tester.takeException(), isNull);

    for (var index = 1; index <= 10; index++) {
      await tester.enterText(input, '连续消息 $index');
      await tester.pump();
      await tester.tap(send);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('连续消息 $index'), findsOneWidget);
    }
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('连续消息 10'), findsOneWidget);
    expect(tester.widget<TextField>(input).focusNode?.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct chat copies a local text message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('周末 KING CLUB 见？'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('direct-chat-copy')));
    await tester.pumpAndSettle();
    expect(find.text('已复制'), findsOneWidget);
  });

  testWidgets('direct chat quotes and recalls with confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('周末 KING CLUB 见？'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('引用'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('direct-chat-quote-draft')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('direct-chat-input')),
      '收到',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('direct-chat-send')));
    await tester.tap(find.byKey(const ValueKey('direct-chat-send')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('收到'), findsOneWidget);
    expect(find.byKey(const ValueKey('direct-chat-quote-draft')), findsNothing);

    await tester.longPress(find.text('好，晚上九点。').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('direct-chat-recall')));
    await tester.pumpAndSettle();
    expect(find.text('撤回这条消息？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('direct-chat-confirm-撤回')));
    await tester.pumpAndSettle();
    expect(find.text('你撤回了一条消息'), findsOneWidget);
  });

  testWidgets(
    'direct chat details keeps settings and clear confirmation fake',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KingTheme.dark,
          home: const DirectChatDetailsPage(peerName: '卡座搭子'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('聊天详情'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('direct-chat-details-muted')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('direct-chat-details-clear')));
      await tester.pumpAndSettle();
      expect(find.text('再次确认清空聊天记录'), findsOneWidget);
      expect(find.textContaining('对方的聊天记录不受影响'), findsOneWidget);
    },
  );

  testWidgets('contact selector searches one friend and confirms forwarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const ContactSelectorPage()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('contact-selector-search')),
      '艾琳',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('contact-selector-艾琳')), findsOneWidget);
    expect(find.text('阿浩'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('contact-selector-艾琳')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('contact-selector-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('contact-selector-submit')));
    await tester.pumpAndSettle();
    expect(find.text('发送给 艾琳'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('contact-selector-confirm')),
      findsOneWidget,
    );
  });

  testWidgets('friend requests and add friend reproduce legacy fake flows', (
    tester,
  ) async {
    var addOpened = false;
    String? chatPeer;
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: FriendRequestsPage(
          onOpenAddFriend: () => addOpened = true,
          onOpenChat: (peerName) => chatPeer = peerName,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('新的朋友'), findsOneWidget);
    expect(find.text('林晓悦'), findsOneWidget);
    expect(find.text('阿澈'), findsOneWidget);
    expect(find.text('查看'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('friend-request-0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('不会建立真实好友关系'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('friend-request-accept')));
    await tester.pumpAndSettle();
    expect(find.text('已添加好友'), findsOneWidget);
    expect(find.text('你已添加了林晓悦，现在可以开始聊天了。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('friend-accepted-message')));
    await tester.pumpAndSettle();
    expect(chatPeer, '林晓悦');
    expect(find.text('已添加'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('friend-request-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('friend-request-message')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('friend-request-accept')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('friend-request-message')));
    await tester.pumpAndSettle();
    expect(chatPeer, '林晓悦');

    await tester.tap(find.byKey(const ValueKey('friend-requests-add')));
    expect(addOpened, isTrue);

    var scanOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AddFriendPage(onOpenScanner: () async => scanOpened = true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加朋友'), findsOneWidget);
    expect(find.text('扫一扫'), findsOneWidget);
    expect(find.text('扫描二维码名片'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-friend-fake-qr')), findsOneWidget);
    expect(find.text('我的短期好友二维码'), findsOneWidget);
    expect(find.textContaining('K45600000199'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('add-friend-scan')));
    await tester.pump();
    expect(scanOpened, isTrue);
  });

  testWidgets('private storage reproduces legacy empty cabinet interactions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: const Scaffold(body: PrivateStoragePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('私人储物柜'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('storage-tab-酒-selected')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('storage-grid-酒-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('storage-tab-物-idle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('storage-tab-物-selected')),
      findsOneWidget,
    );

    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('storage-grid-物-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('storage-empty-info')));
    await tester.pumpAndSettle();
    expect(find.text('当前没有可展示的物品'), findsOneWidget);
    expect(find.textContaining('有效存酒或物品'), findsOneWidget);
    expect(find.text('查看取件凭证'), findsOneWidget);
    expect(find.textContaining('Fake'), findsNothing);
    expect(find.textContaining('Mock'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('storage-open-pickup-demo')));
    await tester.pumpAndSettle();
    expect(find.text('取件凭证'), findsOneWidget);
    expect(find.text('ITEM PICKUP CODE'), findsOneWidget);
    expect(find.text('轩尼诗 VSOP'), findsOneWidget);
    expect(find.textContaining('秒后自动更新'), findsOneWidget);
    expect(find.textContaining('UI Mock'), findsNothing);
  });

  testWidgets('storage pickup code covers offline and partial states', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: const StoragePickupCodePage(
          scenario: StoragePickupScenario.offline,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('当前离线'), findsOneWidget);
    expect(find.text('离线，需人工核验'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: const StoragePickupCodePage(
          scenario: StoragePickupScenario.partial,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('35%（部分交付）'), findsOneWidget);
    expect(find.text('部分交付，剩余可取'), findsOneWidget);
  });

  testWidgets('my profile reproduces legacy content and fake interactions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: const Scaffold(body: MyProfilePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('my-profile-empty-avatar')),
      findsOneWidget,
    );
    expect(find.text('杨嘉琪'), findsOneWidget);
    expect(find.text('青铜 L-0'), findsOneWidget);
    expect(find.text('账号：K45600000199'), findsOneWidget);
    expect(find.text('获赞'), findsOneWidget);
    expect(find.text('关注'), findsOneWidget);
    expect(find.text('互关'), findsOneWidget);
    expect(find.text('粉丝'), findsOneWidget);
    expect(find.text('余额：¥ 0.00'), findsOneWidget);
    expect(find.text('♂ 24岁'), findsOneWidget);
    expect(find.text('颜值：148'), findsOneWidget);
    expect(find.text('河南省 · 安阳市'), findsOneWidget);
    expect(find.text('木系灵根'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('my-profile-dynamic-arrow')),
      findsOneWidget,
    );

    final worksTab = find.byKey(const ValueKey('my-profile-tab-作品'));
    await tester.ensureVisible(worksTab);
    await tester.tap(worksTab);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('my-profile-content-0')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('my-profile-dynamic-arrow')),
      findsNothing,
    );
    final albumTab = find.byKey(const ValueKey('my-profile-tab-相册'));
    await tester.ensureVisible(albumTab);
    await tester.tap(albumTab);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('my-profile-content-2')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('my-profile-dynamic-arrow')),
      findsNothing,
    );
    final activityTab = find.byKey(const ValueKey('my-profile-tab-动态'));
    await tester.tap(activityTab);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('my-profile-dynamic-arrow')),
      findsOneWidget,
    );

    final qrEntry = find.byKey(const ValueKey('my-profile-qr'));
    await tester.ensureVisible(qrEntry);
    await tester.tap(qrEntry);
    await tester.pumpAndSettle();
    expect(find.text('我的二维码'), findsOneWidget);
    expect(find.textContaining('不包含你的永久账号'), findsOneWidget);
    expect(find.textContaining('有效期'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('personal-qr-back')));
    await tester.pumpAndSettle();

    final settingsEntry = find.byKey(const ValueKey('my-profile-settings'));
    await tester.ensureVisible(settingsEntry);
    await tester.tap(settingsEntry);
    await tester.pumpAndSettle();
    expect(find.text('支付安全'), findsOneWidget);
    expect(find.text('账号注销'), findsOneWidget);
    expect(find.text('注销登录'), findsOneWidget);
  });

  testWidgets('my profile order entry opens the shared order center intent', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: Scaffold(body: MyProfilePage(onOpenOrders: () => opened = true)),
      ),
    );
    await tester.pumpAndSettle();

    final orders = find.byKey(const ValueKey('my-profile-orders'));
    await tester.scrollUntilVisible(
      orders,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(orders);
    expect(opened, isTrue);
  });

  testWidgets('my profile asset and order pills have identical heights', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: const Scaffold(body: MyProfilePage()),
      ),
    );
    await tester.pumpAndSettle();

    final keys = [
      const ValueKey('my-profile-asset-我的余额'),
      const ValueKey('my-profile-asset-金币'),
      const ValueKey('my-profile-asset-钻石'),
      const ValueKey('my-profile-orders'),
    ];
    final heights = keys
        .map((key) => tester.getSize(find.byKey(key)).height)
        .toList();

    expect(heights, everyElement(34));
  });

  testWidgets('my profile applies a saved local cover immediately', (
    tester,
  ) async {
    String? receivedCover;
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: Scaffold(
          body: MyProfilePage(
            onOpenEditProfile: (nickname, signature, coverAsset) async {
              receivedCover = coverAsset;
              return const EditableProfileResult(
                nickname: '杨嘉琪',
                signature: '',
                coverAsset: 'assets/legacy/home/mock_poster_music.png',
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final edit = find.byKey(const ValueKey('my-profile-edit'));
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(receivedCover, kDefaultProfileCoverAsset);

    final coverImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('my-profile-cover')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (coverImage.image as AssetImage).assetName,
      'assets/legacy/home/mock_poster_music.png',
    );
  });

  testWidgets('profile internal pages keep legacy offline interactions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: const EditProfilePage(nickname: '杨嘉琪', signature: ''),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('我的个人信息'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('edit-profile-empty-avatar')),
      findsOneWidget,
    );
    expect(find.text('兴趣偏好'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit-profile-nickname')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-profile-input-nickname')),
      'King 测试用户',
    );
    await tester.tap(find.text('确认修改'));
    await tester.pumpAndSettle();
    expect(find.text('King 测试用户'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const PersonalQrPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('我的二维码'), findsOneWidget);
    expect(find.byKey(const ValueKey('personal-qr-refresh')), findsOneWidget);
    expect(find.textContaining('有效期'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const SettingsPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('支付安全'), findsOneWidget);
    expect(find.text('12.8 MB'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-cache')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认清理'));
    await tester.pumpAndSettle();
    expect(find.text('0 B'), findsOneWidget);
  });

  testWidgets('payment security completes the six digit fake PIN flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const PaymentSecurityPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('支付 PIN 已设置'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('payment-pin-forgot')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('payment-pin-input-sms')),
      '888888',
    );
    await tester.tap(find.byKey(const ValueKey('payment-pin-submit-sms')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('payment-pin-input-new')),
      '135790',
    );
    await tester.tap(find.byKey(const ValueKey('payment-pin-submit-new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('payment-pin-input-confirm')),
      '135790',
    );
    await tester.tap(find.byKey(const ValueKey('payment-pin-submit-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('支付 PIN 修改成功'), findsOneWidget);
    expect(find.text('新的支付 PIN 已生效，请妥善保管。'), findsOneWidget);
  });

  testWidgets('account deletion uses preflight, reauth and final phrase', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const AccountDeletionPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('永久注销 KingClub'), findsOneWidget);
    expect(find.text('无未结订单'), findsOneWidget);
    expect(find.textContaining('物业账号'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-deletion-ack')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('account-deletion-start')),
    );
    await tester.tap(find.byKey(const ValueKey('account-deletion-start')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-deletion-sms-input')),
      '888888',
    );
    await tester.tap(find.text('验证'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-deletion-confirm-input')),
      '永久注销',
    );
    await tester.tap(find.text('确认永久注销'));
    await tester.pumpAndSettle();
    expect(find.text('KingClub 账号已注销'), findsOneWidget);
  });

  testWidgets('about catalog opens a pre-release legal document', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const AboutLegalPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('关于 KingClub'), findsOneWidget);
    expect(find.text('KING CLUB 会员服务协议'), findsOneWidget);
    expect(find.text('KingClub 隐私政策'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('about-legal-document-0')));
    await tester.pumpAndSettle();
    expect(find.text('《KING CLUB 会员服务协议》'), findsOneWidget);
    expect(find.text('版本：预发布版'), findsOneWidget);
    expect(find.text('文档内容以正式发布版本为准。'), findsOneWidget);
  });
}
