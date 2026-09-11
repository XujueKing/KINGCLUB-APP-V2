import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/core/mock/mock_runtime.dart';
import 'package:kingclub/src/features/auth/presentation/legacy_welcome_page.dart';
import 'package:kingclub/src/features/auth/presentation/mobile_login_page.dart';
import 'package:kingclub/src/features/onboarding/presentation/membership_image_submission_page.dart';
import 'package:kingclub/src/features/onboarding/presentation/membership_review_status_page.dart';
import 'package:kingclub/src/features/onboarding/presentation/real_name_adult_verification_page.dart';

Widget _app(MockRuntime runtime, Widget child) => ProviderScope(
  overrides: [mockRuntimeProvider.overrideWithValue(runtime)],
  child: MaterialApp(
    key: const ValueKey('registration-base-app'),
    theme: KingTheme.dark,
    home: child,
  ),
);

Widget _scaledApp(
  MockRuntime runtime,
  Widget home, {
  required double textScale,
}) => ProviderScope(
  overrides: [mockRuntimeProvider.overrideWithValue(runtime)],
  child: MaterialApp(
    key: ValueKey('registration-scaled-app-$textScale'),
    theme: KingTheme.dark,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  ),
);

Future<void> _completeIdentity(
  WidgetTester tester,
  MockRuntime runtime,
  String flowId,
) async {
  final future = runtime.submitPhotoIdentity(
    flowId: flowId,
    name: '测试会员',
    identityNumber: '430102199001011234',
  );
  await tester.pump(const Duration(milliseconds: 700));
  final result = await future;
  expect(result, PhotoIdentityOutcome.verifiedAdult);
}

Future<void> _addPhoto(WidgetTester tester, String source) async {
  await tester.tap(find.text('点击添加').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(source));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  testWidgets('identity action aligns with login NEXT at phone sizes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [
      const Size(360, 800),
      const Size(393, 852),
      const Size(430, 932),
    ]) {
      await tester.binding.setSurfaceSize(size);
      final runtime = MockRuntime();
      await tester.pumpWidget(
        _app(runtime, MobileLoginPage(onBack: () {}, onVerified: (_) {})),
      );
      await tester.pump();
      final next = tester.getRect(
        find.byKey(const ValueKey('mobile-login-next')),
      );
      await tester.pumpWidget(
        _app(
          runtime,
          RealNameAdultVerificationPage(
            flowId: runtime.startOnboarding(),
            onBack: () {},
            onNext: () {},
            onInvalidFlow: () {},
          ),
        ),
      );
      await tester.pump();
      final action = tester.getRect(
        find.byKey(const ValueKey('real-name-verify-button')),
      );
      expect(action.top, closeTo(next.top, .5));
      expect(action.bottom, closeTo(next.bottom, .5));
      for (final label in ['NAME:', 'ID CARD:', '未满18岁未成年人\n不得饮酒注册会员']) {
        expect(
          tester.getCenter(find.text(label)).dx,
          closeTo(size.width / 2, .5),
        );
      }
    }
  });
  testWidgets('identity fields and action stay horizontally centered', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final runtime = MockRuntime();
    await tester.pumpWidget(
      _app(
        runtime,
        RealNameAdultVerificationPage(
          flowId: runtime.startOnboarding(),
          onBack: () {},
          onNext: () {},
          onInvalidFlow: () {},
        ),
      ),
    );
    await tester.pump();
    for (final key in [
      'real-name-name-field',
      'real-name-id-field',
      'real-name-verify-button',
    ]) {
      expect(
        tester.getCenter(find.byKey(ValueKey(key))).dx,
        closeTo(393 / 2, .5),
      );
    }
    final surfaces = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (widget) =>
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).gradient is RadialGradient,
        );
    expect(surfaces.length, 2);
    for (final surface in surfaces) {
      final gradient =
          (surface.decoration as BoxDecoration).gradient! as RadialGradient;
      // A 300dp circle spans the field; a radius of 1 collapses to its height.
      expect(gradient.radius * 46, closeTo(300, .1));
    }
  });
  testWidgets('registration screens reflow at supported phone sizes', (
    tester,
  ) async {
    const configurations = <(Size, double)>[
      (Size(360, 800), 1),
      (Size(393, 852), 1.3),
      (Size(430, 932), 2),
    ];
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final configuration in configurations) {
      await tester.binding.setSurfaceSize(configuration.$1);
      final runtime = MockRuntime();
      final flowId = runtime.startOnboarding();

      final pages = <(Widget, Finder)>[
        (
          LegacyWelcomePage(
            onNext: () {},
            onOpenTerms: () {},
            onOpenPrivacy: () {},
          ),
          find.byKey(const ValueKey('legacy-welcome-next')),
        ),
        (
          MobileLoginPage(onBack: () {}, onVerified: (_) {}),
          find.byKey(const ValueKey('mobile-login-next')),
        ),
        (
          RealNameAdultVerificationPage(
            flowId: flowId,
            onBack: () {},
            onNext: () {},
            onInvalidFlow: () {},
          ),
          find.byKey(const ValueKey('real-name-verify-button')),
        ),
        (
          MembershipImageSubmissionPage(
            flowId: flowId,
            onBack: () {},
            onNext: () {},
            onInvalidFlow: () {},
          ),
          find.text('提交并评分'),
        ),
        (
          MembershipReviewStatusPage(
            flowId: flowId,
            onApproved: () {},
            onFixImages: () {},
            onExit: () {},
            onInvalidFlow: () {},
          ),
          find.text('刷新状态'),
        ),
      ];

      for (final page in pages) {
        await tester.pumpWidget(
          _scaledApp(runtime, page.$1, textScale: configuration.$2),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(page.$2, findsOneWidget);
        await tester.ensureVisible(page.$2);
        await tester.pump();
        final actionCenter = tester.getCenter(page.$2);
        expect(actionCenter.dx, inInclusiveRange(0, configuration.$1.width));
        expect(actionCenter.dy, inInclusiveRange(0, configuration.$1.height));
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(null);
    await tester.pump();
  });

  testWidgets('approved member login skips paid registration checks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final runtime = MockRuntime();
    runtime.seedApprovedMember('13800000003');
    var entered = false;
    var onboardingStarted = false;
    await tester.pumpWidget(
      _app(
        runtime,
        MobileLoginPage(
          onBack: () {},
          onAuthenticatedMember: () => entered = true,
          onVerified: (_) => onboardingStarted = true,
        ),
      ),
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('mobile-login-phone-field')),
        matching: find.byType(EditableText),
      ),
      '13800000003',
    );
    await tester.tap(find.byKey(const ValueKey('mobile-login-request-code')));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('mobile-login-code-field')),
        matching: find.byType(EditableText),
      ),
      '888888',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('mobile-login-next')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('mobile-login-next')));
    await tester.pump(const Duration(milliseconds: 850));

    expect(entered, isTrue);
    expect(onboardingStarted, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('photo identity failure is recoverable and never advances', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final runtime = MockRuntime();
    final flowId = runtime.startOnboarding();
    var advanced = false;
    runtime.setNextIdentityOutcome(PhotoIdentityOutcome.identityMismatch);

    await tester.pumpWidget(
      _app(
        runtime,
        RealNameAdultVerificationPage(
          flowId: flowId,
          onBack: () {},
          onNext: () => advanced = true,
          onInvalidFlow: () {},
        ),
      ),
    );
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
    await tester.ensureVisible(
      find.byKey(const ValueKey('real-name-verify-button')),
    );
    await tester.tap(find.byKey(const ValueKey('real-name-verify-button')));
    await tester.pump(const Duration(milliseconds: 700));

    expect(advanced, isFalse);
    expect(find.textContaining('照片与实名信息不一致'), findsOneWidget);
    expect(runtime.onboardingSnapshot(flowId)?.identityVerified, isFalse);

    await tester.tap(find.byKey(const ValueKey('real-name-verify-button')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(advanced, isTrue);
    expect(runtime.onboardingSnapshot(flowId)?.identityVerified, isTrue);
    expect(
      runtime.onboardingSnapshot(flowId)?.photoSlots,
      contains(RegistrationPhotoSlot.selfie),
    );
  });

  testWidgets('low appearance score waits for review and supports reupload', (
    tester,
  ) async {
    final runtime = MockRuntime();
    final flowId = runtime.startOnboarding();
    await _completeIdentity(tester, runtime, flowId);
    runtime.setNextAppearanceOutcome(AppearanceAssessmentOutcome.manualReview);
    var submitted = false;

    await tester.pumpWidget(
      _app(
        runtime,
        MembershipImageSubmissionPage(
          flowId: flowId,
          onBack: () {},
          onNext: () => submitted = true,
          onInvalidFlow: () {},
        ),
      ),
    );
    await _addPhoto(tester, '拍摄照片');
    await _addPhoto(tester, '从相册选择');
    expect(find.text('已上传 · 点击替换'), findsNWidgets(2));

    await tester.tap(find.text('提交并评分'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(submitted, isTrue);
    expect(
      runtime.onboardingSnapshot(flowId)?.reviewStatus,
      ReviewStatus.appearanceReview,
    );

    var reupload = false;
    var entered = false;
    await tester.pumpWidget(
      _app(
        runtime,
        MembershipReviewStatusPage(
          flowId: flowId,
          onApproved: () => entered = true,
          onFixImages: () => reupload = true,
          onExit: () {},
          onInvalidFlow: () {},
        ),
      ),
    );
    expect(find.text('颜值分数不够，等待审核'), findsOneWidget);
    expect(find.text('重新上传照片'), findsOneWidget);
    expect(find.text('进入 KingClub'), findsNothing);
    await tester.tap(find.text('重新上传照片'));
    expect(reupload, isTrue);

    runtime.setReviewFixture(flowId, ReviewStatus.approved);
    await tester.tap(find.text('刷新审核状态'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('会员申请已通过'), findsOneWidget);
    await tester.tap(find.text('进入 KingClub'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(entered, isTrue);
  });

  test('replacing a scored photo revokes cached entry permission', () async {
    final runtime = MockRuntime();
    final flowId = runtime.startOnboarding();
    final identityResult = await runtime.submitPhotoIdentity(
      flowId: flowId,
      name: '测试会员',
      identityNumber: '430102199001011234',
    );
    expect(identityResult, PhotoIdentityOutcome.verifiedAdult);
    await runtime.stageRegistrationPhoto(
      flowId: flowId,
      slot: RegistrationPhotoSlot.portrait,
    );
    await runtime.stageRegistrationPhoto(
      flowId: flowId,
      slot: RegistrationPhotoSlot.outfit,
    );
    expect(
      await runtime.submitAppearanceAssessment(flowId),
      AppearanceAssessmentOutcome.qualified,
    );
    expect(runtime.canEnterApp(flowId), isTrue);

    await runtime.stageRegistrationPhoto(
      flowId: flowId,
      slot: RegistrationPhotoSlot.portrait,
    );
    expect(runtime.canEnterApp(flowId), isFalse);
    expect(
      runtime.onboardingSnapshot(flowId)?.reviewStatus,
      ReviewStatus.pending,
    );
  });
}
