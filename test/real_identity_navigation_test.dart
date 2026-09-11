import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/networking/kingclub_secure_client.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/data/auth_repository_provider.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/onboarding/data/real_identity_repository.dart';
import 'package:kingclub/src/features/onboarding/presentation/real_name_adult_verification_page.dart';

class _VerifiedIdentity extends RealIdentityRepository {
  _VerifiedIdentity()
    : super(
        KingclubSecureClient('https://example.invalid'),
        SecureSessionStore(),
        'https://example.invalid',
      );
  @override
  Future<Map<String, dynamic>> status() async => {
    'state': 'verified',
    'providerAvailable': true,
  };
}

class _RefreshAuth extends RealAuthRepository {
  _RefreshAuth(this.update)
    : super(
        KingclubSecureClient('https://example.invalid'),
        SecureSessionStore(),
      );
  final void Function(AuthLoginResult) update;
  @override
  Future<AuthLoginResult> refreshMembership() async {
    const result = AuthLoginResult(
      isNewMembership: false,
      membershipStatus: 'active',
      registrationStatus: 'photos_required',
      isRealSession: true,
    );
    update(result);
    return result;
  }
}

void main() {
  testWidgets(
    'verified identity survives the route transition without redirecting to login',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          realIdentityRepositoryProvider.overrideWithValue(_VerifiedIdentity()),
          authRepositoryProvider.overrideWith(
            (ref) => _RefreshAuth(
              ref.read(authenticatedMemberProvider.notifier).update,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(authenticatedMemberProvider.notifier)
          .update(
            const AuthLoginResult(
              isNewMembership: true,
              membershipStatus: 'active',
              isRealSession: true,
            ),
          );
      var next = 0;
      var invalid = 0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: RealNameAdultVerificationPage(
              flowId: 'real-registration',
              onBack: () {},
              onNext: () => next++,
              onInvalidFlow: () => invalid++,
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('real-name-name-field')),
        '测试资料',
      );
      await tester.enterText(
        find.byKey(const ValueKey('real-name-id-field')),
        '000000000000000000',
      );
      final button = find.byKey(const ValueKey('real-name-verify-button'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(next, 1);
      expect(invalid, 0);
      expect(
        container.read(authenticatedMemberProvider)?.registrationStatus,
        'photos_required',
      );
    },
  );
}
