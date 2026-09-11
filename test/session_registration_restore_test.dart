import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/app.dart';
import 'package:kingclub/src/core/networking/kingclub_secure_client.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/data/auth_repository_provider.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/auth/presentation/legacy_welcome_page.dart';
import 'package:kingclub/src/navigation/app_router.dart';

class _Store extends SecureSessionStore {
  Map<String, dynamic>? saved = {
    'sessionId': 'fixture-session',
    'apiKeyId': 'fixture-key',
    'apiKey': 'fixture-secret',
    'refreshToken': 'fixture-refresh',
    'refreshTokenVersion': 1,
    'refreshExpiresAt': DateTime.now()
        .add(const Duration(days: 2))
        .toIso8601String(),
    'membership': {'registrationStatus': 'identity_required'},
  };
  @override
  Future<Map<String, dynamic>?> readSession() async => saved;
  @override
  Future<void> saveSession(Map<String, dynamic> value) async {
    saved = value;
  }

  @override
  Future<void> clearSession() async {
    saved = null;
  }

  @override
  Future<String> deviceId() async => 'fixture-device';
}

class _Client extends KingclubSecureClient {
  _Client({this.firstError, this.waitForResponse})
    : super('https://example.invalid');
  final Future<void>? waitForResponse;
  String? firstError;
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> call(
    String id,
    Map<String, dynamic> params, {
    Map<String, dynamic>? session,
    Duration? receiveTimeout,
  }) async {
    calls.add(id);
    if (waitForResponse != null) await waitForResponse;
    if (firstError != null) {
      final code = firstError!;
      firstError = null;
      throw AuthFailure(code, 'fixture failure');
    }
    if (id == 'K260824000103') {
      return {
        'apiKeyId': 'rotated-key',
        'apiKey': 'rotated-secret',
        'refreshToken': 'rotated-refresh',
        'refreshTokenVersion': 2,
      };
    }
    if (id != 'K260824000104') throw StateError('Unexpected verification call');
    return {
      'account': {'accountStatus': 'active'},
      'membership': {
        'status': 'active',
        'registrationStatus': 'photos_required',
      },
    };
  }
}

void main() {
  testWidgets(
    'pending cold restoration shows the existing welcome instead of a loading page',
    (tester) async {
      final gate = Completer<void>();
      final client = _Client(waitForResponse: gate.future);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith(
            (ref) => RealAuthRepository(
              client,
              _Store(),
              onAuthenticated: ref
                  .read(authenticatedMemberProvider.notifier)
                  .update,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const KingClubApp(),
        ),
      );
      await tester.pump();
      expect(find.byType(LegacyWelcomePage), findsOneWidget);
      expect(find.byKey(const ValueKey('legacy-welcome-logo')), findsOneWidget);
      expect(find.text('正在恢复登录和注册进度'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('完善会员形象资料'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('server progress wins over stale local identity state', () async {
    final client = _Client();
    final result = await RealAuthRepository(client, _Store()).restoreSession();
    expect(result?.needsImages, true);
    expect(result?.needsIdentity, false);
    expect(client.calls, ['K260824000104']);
  });
  test('expired access refreshes credentials once then reads registration progress', () async {
    final client = _Client(firstError: 'SESSION_EXPIRED');
    final store = _Store();
    final result = await RealAuthRepository(client, store).restoreSession();
    expect(result?.needsImages, true);
    expect(store.saved?['apiKeyId'], 'rotated-key');
    expect(client.calls, ['K260824000104', 'K260824000103', 'K260824000104']);
  });
  test('network failure preserves saved login for retry', () async {
    final store = _Store();
    await expectLater(
      RealAuthRepository(
        _Client(firstError: 'NETWORK_ERROR'),
        store,
      ).restoreSession(),
      throwsA(isA<AuthFailure>()),
    );
    expect(store.saved, isNotNull);
  });
  test(
    'revoked session returns to authentication without identity reset',
    () async {
      final store = _Store();
      expect(
        await RealAuthRepository(
          _Client(firstError: 'AUTH_SESSION_REVOKED'),
          store,
        ).restoreSession(),
        isNull,
      );
      expect(store.saved, isNull);
    },
  );
  testWidgets(
    'cold launch and stale identity route both resume image details',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = _Store();
      final client = _Client();
      for (var launch = 0; launch < 2; launch++) {
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWith(
              (ref) => RealAuthRepository(
                client,
                store,
                onAuthenticated: ref
                    .read(authenticatedMemberProvider.notifier)
                    .update,
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const KingClubApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('完善会员形象资料'), findsOneWidget);
        expect(find.byKey(const ValueKey('real-name-id-field')), findsNothing);
        container
            .read(appRouterProvider)
            .go(
              '/onboarding/identity',
              extra: const OnboardingFlowRouteArgs('real-registration'),
            );
        await tester.pumpAndSettle();
        expect(find.text('完善会员形象资料'), findsOneWidget);
        expect(find.byKey(const ValueKey('real-name-id-field')), findsNothing);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(
          container
              .read(appRouterProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/auth/welcome',
        );
        expect(container.read(authenticatedMemberProvider)?.needsImages, true);
        final requestsBeforeContinue = client.calls.length;
        tester
            .widget<LegacyWelcomePage>(find.byType(LegacyWelcomePage))
            .onNext();
        await tester.pumpAndSettle();
        expect(client.calls.length, requestsBeforeContinue);
        expect(find.text('完善会员形象资料'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      }
      expect(client.calls.every((id) => id == 'K260824000104'), true);
    },
  );
}
