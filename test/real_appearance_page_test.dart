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
