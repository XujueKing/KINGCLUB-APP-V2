import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/networking/kingclub_secure_client.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/data/auth_repository_provider.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/auth/presentation/auth_bootstrap_page.dart';
import 'package:kingclub/src/features/auth/presentation/legacy_welcome_page.dart';

class _Repository extends RealAuthRepository {
  _Repository(this.pending)
    : super(
        KingclubSecureClient('https://example.invalid'),
        SecureSessionStore(),
      );
  final Future<AuthLoginResult?> pending;
  @override
  Future<AuthLoginResult?> restoreForBootstrap() => pending;
}

void main() {
  testWidgets('pending login restoration never renders welcome cover', (
    tester,
  ) async {
    final gate = Completer<AuthLoginResult?>();
    var authenticated = 0;
    var anonymous = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_Repository(gate.future)),
        ],
        child: MaterialApp(
          home: AuthBootstrapPage(
            onAnonymous: () => anonymous++,
            onAuthenticated: () => authenticated++,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LegacyWelcomePage), findsNothing);
    expect(authenticated, 0);
    gate.complete(
      const AuthLoginResult(
        isNewMembership: false,
        membershipStatus: 'active',
        registrationStatus: 'approved',
        isRealSession: true,
      ),
    );
    await tester.pump();
    expect(authenticated, 1);
    expect(anonymous, 0);
    expect(find.byType(LegacyWelcomePage), findsNothing);
  });
  testWidgets('anonymous restoration uses anonymous destination', (
    tester,
  ) async {
    var anonymous = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _Repository(Future.value(null)),
          ),
        ],
        child: MaterialApp(
          home: AuthBootstrapPage(
            onAnonymous: () => anonymous++,
            onAuthenticated: () => fail('Unexpected login'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(anonymous, 1);
  });
}
