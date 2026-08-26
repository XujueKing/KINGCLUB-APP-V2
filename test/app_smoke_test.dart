import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/app.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/presentation/private_storage_page.dart';
import 'package:kingclub/src/features/content/presentation/content_feed_page.dart';
import 'package:kingclub/src/features/contacts/presentation/contacts_page.dart';
import 'package:kingclub/src/features/contacts/presentation/friendship_pages.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';
import 'package:kingclub/src/features/scanner/presentation/safe_scanner_page.dart';
import 'package:kingclub/src/features/shell/presentation/app_shell_page.dart';

void main() {
  testWidgets('anonymous bootstrap opens mobile login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KingClubApp()));
    expect(find.text('正在安全检查登录状态'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.text('手机号登录'), findsOneWidget);
    expect(find.text('获取验证码'), findsOneWidget);
  });

  testWidgets('mock sms and onboarding flow reaches the app shell', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KingClubApp()));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), '13800000000');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('获取验证码'));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(find.text('输入验证码'), findsOneWidget);
    expect(find.text('UI 测试验证码'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), '888888');
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pumpAndSettle();

    expect(find.text('实名与成年核验'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('开始 Fake 核验'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('完善会员形象资料'), findsOneWidget);
    await tester.tap(find.text('点击添加').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用合成示例图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('点击添加').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用合成示例图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('你的风格偏好'), findsOneWidget);
    await tester.ensureVisible(find.text('暂时跳过'));
    await tester.tap(find.text('暂时跳过'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('完善兴趣偏好'), findsOneWidget);
    await tester.ensureVisible(find.text('跳过偏好并提交'));
    await tester.tap(find.text('跳过偏好并提交'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('会员申请审核中'), findsOneWidget);
    await tester.tap(find.text('UI 测试场景'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('已通过'));
    await tester.tap(find.text('已通过'));
    await tester.pump();
    await tester.ensureVisible(find.text('进入 KingClub'));
    await tester.tap(find.text('进入 KingClub'));
    await tester.pumpAndSettle();

    expect(find.text('青铜'), findsOneWidget);
    expect(find.text('L-0 EXP:50'), findsOneWidget);
    expect(find.text('一起玩'), findsOneWidget);
    expect(find.text('组局玩'), findsOneWidget);
    expect(find.text('SCAN QR'), findsOneWidget);
    expect(find.bySemanticsLabel('首页，标签，已选中'), findsOneWidget);
    expect(find.bySemanticsLabel('消息，标签'), findsOneWidget);
    expect(find.bySemanticsLabel('内容，标签'), findsOneWidget);
    expect(find.bySemanticsLabel('私人储物柜，标签'), findsOneWidget);
    expect(find.bySemanticsLabel('我的，标签'), findsOneWidget);

    await tester.tap(find.text('一起玩'));
    await tester.pumpAndSettle();
    expect(find.text('一起玩AA预定'), findsOneWidget);
    expect(find.text('一键随机选座'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('组局玩'));
    await tester.pumpAndSettle();
    expect(find.text('VIP组局'), findsOneWidget);
    expect(find.text('预定一个新卡座'), findsOneWidget);
  });

  testWidgets('mock sms rate limit stays on mobile login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KingClubApp()));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), '13800000001');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('获取验证码'));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(find.text('请求过于频繁，请 60 秒后重试'), findsOneWidget);
    expect(find.text('手机号登录'), findsOneWidget);
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
    expect(find.text('静音'), findsOneWidget);
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
    expect(find.text('卡座搭子'), findsOneWidget);
    expect(find.textContaining('手机号'), findsNothing);
    expect(find.text('仅 KingClub 好友'), findsNothing);
    expect(find.byTooltip('UI 测试场景'), findsNothing);
    expect(find.byTooltip('更多'), findsNothing);

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
    expect(find.bySemanticsLabel('消息，标签，已选中'), findsOneWidget);

    await tester.tap(find.text('通讯录'));
    await tester.pumpAndSettle();
    expect(find.text('新的朋友'), findsOneWidget);
  });

  testWidgets('friend requests and add friend reproduce legacy fake flows', (
    tester,
  ) async {
    var addOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: FriendRequestsPage(onOpenAddFriend: () => addOpened = true),
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
    expect(find.text('已验证'), findsOneWidget);

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
    expect(find.text('我的会员码：K45600000199'), findsOneWidget);

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
    expect(find.textContaining('不会查询服务器'), findsOneWidget);
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

    await tester.tap(find.byKey(const ValueKey('my-profile-tab-作品')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('my-profile-content-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('my-profile-tab-相册')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('my-profile-content-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('my-profile-qr')));
    await tester.pumpAndSettle();
    expect(find.text('我的二维码'), findsOneWidget);
    expect(find.textContaining('不含真实身份凭证'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('my-profile-settings')));
    await tester.pumpAndSettle();
    expect(find.text('支付安全'), findsOneWidget);
    expect(find.text('账号注销'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
  });
}
