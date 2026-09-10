import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/data/auth_repository_provider.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/auth/presentation/mobile_login_page.dart';
import 'package:kingclub/src/core/mock/mock_runtime.dart';

class _Auth implements AuthRepository {
  _Auth(this.result);
  final AuthLoginResult result;
  @override
  Future<AuthSmsChallenge> requestSms(String mobile) async =>
      const AuthSmsChallenge(id: 'real-challenge', retryAfterSeconds: 60);
  @override
  Future<AuthLoginResult> login({
    required String mobile,
    required String challengeId,
    required String code,
  }) async => result;
}

void main() {
  for (final isNew in [true, false]) {
    for (final status in [
      'identity_required',
      'pending_review',
      'approved',
      'unknown',
    ]) {
      testWidgets(
        'real login new=$isNew registration=$status uses server status',
        (tester) async {
          tester.view.physicalSize = const Size(430, 932);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final result = RealAuthRepository.parseMembership({
            'isNewMembership': isNew,
            'account': {'accountStatus': 'active'},
            'membership': {'status': 'active', 'registrationStatus': status},
          });
          var destination = '';
          final runtime = MockRuntime();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authRepositoryProvider.overrideWithValue(_Auth(result)),
                mockRuntimeProvider.overrideWithValue(runtime),
              ],
              child: MaterialApp(
                home: MobileLoginPage(
                  onBack: () {},
                  onAuthenticatedMember: () => destination = 'home',
                  onVerified: (id) => destination = id,
                  onRegistrationStatus: () => destination = 'status',
                ),
              ),
            ),
          );
          final fields = find.byType(TextField);
          await tester.enterText(fields.at(0), '13800000000');
          await tester.tap(find.text('获取验证码'));
          await tester.pumpAndSettle();
          await tester.enterText(fields.at(1), '123456');
          await tester.pump();
          await tester.ensureVisible(
            find.byKey(const ValueKey('mobile-login-next')),
          );
          await tester.tap(find.byKey(const ValueKey('mobile-login-next')));
          await tester.pump();
          expect(
            destination,
            status == 'approved'
                ? 'home'
                : status == 'identity_required'
                ? 'real-registration'
                : 'status',
          );
          expect(runtime.hasOnboardingFlow('mock-onboarding-1'), isFalse);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  test(
    'missing registration state and restricted accounts never enter home',
    () {
      for (final membership in [
        {'status': 'active'},
        {'status': 'suspended', 'registrationStatus': 'approved'},
        {'status': 'deleted', 'registrationStatus': 'approved'},
      ]) {
        expect(
          RealAuthRepository.parseMembership({
            'account': {'accountStatus': 'active'},
            'membership': membership,
            'isNewMembership': false,
          }).canEnterApp,
          isFalse,
        );
      }
    },
  );
}
