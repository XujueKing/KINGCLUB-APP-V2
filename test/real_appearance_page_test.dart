import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kingclub/src/core/networking/kingclub_secure_client.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/data/auth_repository_provider.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/onboarding/data/real_identity_repository.dart';
import 'package:kingclub/src/features/onboarding/presentation/membership_image_submission_page.dart';
import 'package:kingclub/src/features/onboarding/presentation/style_music_preferences_page.dart';
import 'package:kingclub/src/features/onboarding/presentation/drink_event_preferences_page.dart';
import 'package:kingclub/src/features/onboarding/presentation/real_membership_status_page.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';

class _Photos extends RealIdentityRepository {
  _Photos()
    : super(
        KingclubSecureClient('https://example.invalid'),
        SecureSessionStore(),
        'https://example.invalid',
      );
  final slots = <String>[];
  var version = 1;
  var submits = 0;
  num? score;
  String state = 'draft';
  Map<String, dynamic> draft = {
    'styles': <String>[],
    'music': <String>[],
    'drinks': <String>[],
    'events': <String>[],
  };
  final finalizations = <bool>[];
  @override
  Future<Map<String, dynamic>> preferences() async => {
    'preferences': draft,
    'version': version,
    'step': finalizations.isEmpty ? 3 : 4,
    'registrationStatus': 'preferences_required',
  };
  @override
  Future<Map<String, dynamic>> savePreferences(
    Map<String, dynamic> values,
    int submittedVersion, {
    required bool finalize,
  }) async {
    expect(submittedVersion, version);
    draft = values;
    finalizations.add(finalize);
    return preferences();
  }

  @override
  Future<Uint8List?> capture({ImageSource source = ImageSource.camera}) async =>
      Uint8List.fromList([1, 2, 3]);
  @override
  Future<String> upload(
    Uint8List bytes,
    void Function(int, int) progress, {
    String? appearanceSlot,
  }) async {
    if (!slots.contains(appearanceSlot)) slots.add(appearanceSlot!);
    version++;
    state = 'draft';
    return 'fixture-photo';
  }

  @override
  Future<Map<String, dynamic>> appearanceStatus() async => {
    'result': {'score': score},
    'state': state,
    'version': version,
    'photos': slots
        .map(
          (slot) => {
            'slot': slot,
            'state': 'uploaded',
            'previewPath': '/fixture.jpg',
          },
        )
        .toList(),
  };
  @override
  Future<Map<String, dynamic>> submitAppearance(
    int submittedVersion,
    String key,
  ) async {
    expect(submittedVersion, version);
    submits++;
    state = 'preferences_required';
    return appearanceStatus();
  }
}

class _Auth extends RealAuthRepository {
  _Auth()
    : super(
        KingclubSecureClient('https://example.invalid'),
        SecureSessionStore(),
      );
  @override
  Future<AuthLoginResult> refreshMembership() async => const AuthLoginResult(
    isNewMembership: false,
    membershipStatus: 'active',
    registrationStatus: 'preferences_required',
    isRealSession: true,
  );
}

void main() {
  testWidgets(
    'rejected and blocked members see only their public decision reason',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          realIdentityRepositoryProvider.overrideWithValue(_Photos()),
        ],
      );
      addTearDown(container.dispose);
      for (final status in ['rejected', 'blocked']) {
        final member = RealAuthRepository.parseMembership({
          'account': {'accountStatus': 'active'},
          'membership': {
            'status': 'active',
            'registrationStatus': status,
            'publicDecisionReason': '已核实的公开原因',
          },
        });
        container.read(authenticatedMemberProvider.notifier).update(member);
        expect(member.canEnterApp, isFalse);
        expect(member.needsImages, isFalse);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: KingTheme.dark,
              home: RealMembershipStatusPage(
                key: ValueKey(status),
                onApproved: () {},
                onIdentity: () {},
                onBack: () {},
                onImages: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(status == 'blocked' ? '入会资格已受限' : '本次申请未通过'),
          findsOneWidget,
        );
        expect(find.text('形象参考评分'), findsNothing);
        expect(find.text('更换形象照片'), findsNothing);
        expect(find.text('进入 KINGCLUB'), findsNothing);
        expect(find.text('希望更快了解审核进度？'), findsNothing);
        await tester.tap(find.text('查看具体原因'));
        await tester.pumpAndSettle();
        expect(find.text('已核实的公开原因'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'approved welcome enters directly while restricted accounts cannot',
    (tester) async {
      final photos = _Photos()..score = 88;
      final container = ProviderContainer(
        overrides: [realIdentityRepositoryProvider.overrideWithValue(photos)],
      );
      addTearDown(container.dispose);
      var entered = false;
      for (final status in ['active', 'suspended']) {
        container
            .read(authenticatedMemberProvider.notifier)
            .update(
              AuthLoginResult(
                isNewMembership: false,
                membershipStatus: status,
                registrationStatus: 'approved',
                isRealSession: true,
              ),
            );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: KingTheme.dark,
              home: RealMembershipStatusPage(
                key: ValueKey(status),
                onApproved: () => entered = true,
                onIdentity: () {},
                onBack: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (status == 'active') {
          expect(find.text('欢迎加入 KINGCLUB'), findsOneWidget);
          expect(find.text('88'), findsOneWidget);
          expect(find.text('希望更快了解审核进度？'), findsNothing);
          expect(find.text('为什么需要等待审核？'), findsNothing);
          expect(find.text('评分仅供本次申请参考，不代表个人价值。最终结果以会员审核为准。'), findsNothing);
          expect(find.text('刷新状态'), findsNothing);
          expect(find.text('更换形象照片'), findsNothing);
          expect(find.text('返回登录页'), findsNothing);
          await tester.tap(find.text('进入 KINGCLUB'));
          expect(entered, isTrue);
          expect(photos.submits, 0);
        } else {
          expect(find.text('进入 KINGCLUB'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'review displays saved score without resubmitting and handles missing score',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final photos = _Photos()..score = 77;
      final container = ProviderContainer(
        overrides: [realIdentityRepositoryProvider.overrideWithValue(photos)],
      );
      addTearDown(container.dispose);
      container
          .read(authenticatedMemberProvider.notifier)
          .update(
            const AuthLoginResult(
              isNewMembership: false,
              membershipStatus: 'active',
              registrationStatus: 'pending_review',
              isRealSession: true,
            ),
          );
      for (final scenario in [
        (size: const Size(320, 568), scale: 1.0, score: 77, open: false),
        (size: const Size(360, 640), scale: 1.0, score: 77, open: false),
        (size: const Size(393, 852), scale: 1.0, score: 77, open: true),
        (size: const Size(430, 932), scale: 1.0, score: 77, open: true),
        (size: const Size(320, 568), scale: 2.0, score: 77, open: false),
        (size: const Size(430, 932), scale: 2.0, score: 77, open: false),
        (size: const Size(360, 800), scale: 1.0, score: null, open: false),
      ]) {
        final score = scenario.score;
        tester.view.physicalSize = scenario.size;
        photos.score = score;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: KingTheme.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scenario.scale),
                  padding: const EdgeInsets.only(top: 44, bottom: 34),
                ),
                child: child!,
              ),
              home: RealMembershipStatusPage(
                key: ValueKey(scenario),
                onApproved: () {},
                onIdentity: () {},
                onBack: () {},
                onImages: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(score == null ? '评分结果待确认' : '77'), findsOneWidget);
        expect(find.text('希望更快了解审核进度？'), findsOneWidget);
        expect(find.text('为什么需要等待审核？'), findsOneWidget);
        final reason = find.textContaining('照片清晰度、拍摄角度或光线');
        expect(reason, scenario.open ? findsOneWidget : findsNothing);
        if (!scenario.open) {
          await tester.ensureVisible(find.text('为什么需要等待审核？'));
          await tester.tap(find.text('为什么需要等待审核？'));
          await tester.pumpAndSettle();
        }
        expect(reason, findsOneWidget);
        expect(
          tester.getRect(find.widgetWithText(FilledButton, '刷新状态')).bottom,
          lessThan(scenario.size.height - 34),
        );
        await tester.ensureVisible(find.text('联系营销人员，协助跟进审核或补充资料。'));
        await tester.pumpAndSettle();
        final marketing = tester.getRect(find.text('联系营销人员，协助跟进审核或补充资料。'));
        final refresh = tester.getRect(
          find.widgetWithText(FilledButton, '刷新状态'),
        );
        expect(marketing.bottom, lessThanOrEqualTo(refresh.top));
        expect(find.text('返回登录页').hitTestable(), findsOneWidget);
        expect(
          tester.getRect(find.widgetWithText(TextButton, '更换形象照片')).bottom,
          lessThanOrEqualTo(refresh.top),
        );
        expect(
          tester.getRect(find.widgetWithText(TextButton, '返回登录页')).top,
          greaterThanOrEqualTo(refresh.bottom),
        );
        await tester.ensureVisible(find.text('为什么需要等待审核？'));
        await tester.tap(find.text('为什么需要等待审核？'));
        await tester.pumpAndSettle();
        expect(reason, findsNothing);
        expect(photos.submits, 0);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'style and music save a draft, only final interest page submits admission',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final photos = _Photos();
      final container = ProviderContainer(
        overrides: [
          realIdentityRepositoryProvider.overrideWithValue(photos),
          authRepositoryProvider.overrideWithValue(_Auth()),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(authenticatedMemberProvider.notifier)
          .update(
            const AuthLoginResult(
              isNewMembership: false,
              membershipStatus: 'active',
              registrationStatus: 'preferences_required',
              isRealSession: true,
            ),
          );
      var advanced = false, submitted = false;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: StyleMusicPreferencesPage(
              flowId: 'real-registration',
              onBack: () {},
              onNext: () => advanced = true,
              onInvalidFlow: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('小清新'));
      await tester.tap(find.text('HOUSE'));
      await tester.ensureVisible(find.text('NEXT'));
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(advanced, true);
      expect(photos.finalizations, [false]);
      expect(photos.draft['styles'], ['fresh']);
      expect(photos.draft['music'], ['house']);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DrinkEventPreferencesPage(
              flowId: 'real-registration',
              onBack: () {},
              onSubmitted: () => submitted = true,
              onInvalidFlow: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('啤酒'));
      await tester.tap(find.text('车友会专场'));
      await tester.ensureVisible(find.text('提交会员申请'));
      await tester.tap(find.text('提交会员申请'));
      await tester.pump();
      await tester.pump();
      expect(submitted, true);
      expect(photos.finalizations, [false, true]);
      expect(photos.draft['styles'], ['fresh']);
      expect(photos.draft['drinks'], ['beer']);
      expect(photos.draft['events'], ['car_club']);
      expect(photos.submits, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'real image slots upload then continue to preferences without early review',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final photos = _Photos();
      final container = ProviderContainer(
        overrides: [
          realIdentityRepositoryProvider.overrideWithValue(photos),
          authRepositoryProvider.overrideWithValue(_Auth()),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(authenticatedMemberProvider.notifier)
          .update(
            const AuthLoginResult(
              isNewMembership: false,
              membershipStatus: 'active',
              registrationStatus: 'photos_required',
              isRealSession: true,
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MembershipImageSubmissionPage(
              flowId: 'real-registration',
              onBack: () {},
              onNext: () {},
              onInvalidFlow: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '提交并评分'))
            .onPressed,
        isNull,
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('点击添加').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('从相册选择'));
        await tester.pumpAndSettle();
      }
      expect(photos.slots, ['portrait', 'outfit']);
      await tester.tap(find.text('提交并评分'));
      await tester.pumpAndSettle();
      expect(photos.submits, 1);
      expect(find.text('下一步 · 选择爱好'), findsOneWidget);
      await tester.tap(find.text('已上传 · 点击替换').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('拍摄照片'));
      await tester.pumpAndSettle();
      expect(photos.version, 4);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '提交并评分'))
            .onPressed,
        isNotNull,
      );
    },
  );
}
