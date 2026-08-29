import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/core/mock/mock_runtime.dart';
import 'package:kingclub/src/features/auth/presentation/sms_verification_page.dart';
import 'package:kingclub/src/features/onboarding/presentation/drink_event_preferences_page.dart';
import 'package:kingclub/src/features/onboarding/presentation/membership_review_status_page.dart';
import 'package:kingclub/src/features/onboarding/presentation/style_music_preferences_page.dart';

Widget _app(MockRuntime runtime, Widget child) => ProviderScope(
  overrides: [mockRuntimeProvider.overrideWithValue(runtime)],
  child: MaterialApp(theme: KingTheme.dark, home: child),
);

void main() {
  testWidgets('sms verification help resend and success remain local', (
    tester,
  ) async {
    final runtime = MockRuntime();
    final flowFuture = runtime.requestSms('13800000000');
    await tester.pump(const Duration(milliseconds: 750));
    final flow = await flowFuture;
    String? verifiedFlow;

    await tester.pumpWidget(
      _app(
        runtime,
        SmsVerificationPage(
          flowId: flow.id,
          onBack: () {},
          onVerified: (flowId) => verifiedFlow = flowId,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('输入验证码'), findsOneWidget);
    await tester.tap(find.text('收不到验证码？'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('短信未被拦截'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pump(const Duration(seconds: 61));
    expect(find.text('重新获取'), findsOneWidget);
    await tester.tap(find.text('重新获取'));
    await tester.pump();
    expect(find.text('验证码已重新发送'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '111111');
    await tester.pump(const Duration(milliseconds: 850));
    expect(find.text('验证码不正确，请重新输入'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '888888');
    await tester.pump(const Duration(milliseconds: 850));
    expect(verifiedFlow, isNotNull);
  });

  testWidgets('style and music preferences select and continue', (
    tester,
  ) async {
    final runtime = MockRuntime();
    final flowId = runtime.startOnboarding();
    var continued = false;

    await tester.pumpWidget(
      _app(
        runtime,
        StyleMusicPreferencesPage(
          flowId: flowId,
          onBack: () {},
          onNext: () => continued = true,
          onInvalidFlow: () {},
        ),
      ),
    );

    expect(find.text('高级酒会小礼服'), findsOneWidget);
    expect(find.text('韩式现代时尚风'), findsOneWidget);
    expect(find.text('BOUNCE'), findsOneWidget);
    expect(find.text('BIG ROOM'), findsOneWidget);

    await tester.tap(find.text('简约通勤'));
    await tester.ensureVisible(find.text('HOUSE'));
    await tester.tap(find.text('HOUSE'));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, '简约通勤'))
          .selected,
      isTrue,
    );
    expect(find.textContaining('Mock'), findsNothing);
    expect(find.textContaining('Fake'), findsNothing);

    await tester.tap(find.text('下一步'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(continued, isTrue);
  });

  testWidgets('drink and event catalog keeps legacy choices and selections', (
    tester,
  ) async {
    final runtime = MockRuntime();
    final flowId = runtime.startOnboarding();
    var submitted = false;

    await tester.pumpWidget(
      _app(
        runtime,
        DrinkEventPreferencesPage(
          flowId: flowId,
          onBack: () {},
          onSubmitted: () => submitted = true,
          onInvalidFlow: () {},
        ),
      ),
    );

    expect(find.text('白兰地'), findsOneWidget);
    expect(find.text('日本清酒'), findsOneWidget);
    expect(find.text('高级小礼服舞会'), findsOneWidget);
    expect(find.text('怀旧经典专场'), findsOneWidget);

    await tester.tap(find.text('白兰地'));
    await tester.ensureVisible(find.text('高级小礼服舞会'));
    await tester.tap(find.text('高级小礼服舞会'));
    await tester.pump();

    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, '白兰地'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, '高级小礼服舞会'))
          .selected,
      isTrue,
    );

    await tester.ensureVisible(find.text('提交会员申请'));
    await tester.tap(find.text('提交会员申请'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(submitted, isTrue);
  });

  testWidgets('review status keeps every formal state actionable', (
    tester,
  ) async {
    final runtime = MockRuntime();
    final flowId = runtime.startOnboarding();
    var approved = false;
    var fixImages = false;

    await tester.pumpWidget(
      _app(
        runtime,
        MembershipReviewStatusPage(
          flowId: flowId,
          onApproved: () => approved = true,
          onFixImages: () => fixImages = true,
          onExit: () {},
          onInvalidFlow: () {},
        ),
      ),
    );

    expect(find.text('会员申请审核中'), findsOneWidget);
    await tester.ensureVisible(find.text('UI 测试场景'));
    await tester.tap(find.text('UI 测试场景'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('补资料'));
    await tester.pump();
    expect(find.text('需要补充资料'), findsOneWidget);
    await tester.tap(find.text('补充形象资料'));
    expect(fixImages, isTrue);

    await tester.tap(find.text('已通过'));
    await tester.pump();
    expect(find.text('进入 KingClub'), findsOneWidget);
    expect(find.text('刷新状态'), findsNothing);
    expect(find.text('退出登录'), findsNothing);
    await tester.tap(find.text('进入 KingClub'));
    expect(approved, isTrue);

    await tester.ensureVisible(find.text('未通过'));
    await tester.tap(find.text('未通过'));
    await tester.pump();
    expect(find.text('本次申请暂未通过，重新申请时间请以页面后续通知为准。'), findsOneWidget);
    expect(find.textContaining('正式策略'), findsNothing);
  });
}
