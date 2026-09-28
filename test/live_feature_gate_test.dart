import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_localizations.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/core/networking/kingclub_secure_client.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/data/auth_repository_provider.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/navigation/app_router.dart';
import 'package:kingclub/src/navigation/live_feature_gate.dart';
import 'package:kingclub/src/navigation/unavailable_feature_page.dart';

class _NoNetwork extends KingclubSecureClient {
  _NoNetwork() : super('https://audit.invalid');

  @override
  Future<Map<String, dynamic>> call(
    String interfaceId,
    Map<String, dynamic> params, {
    Map<String, dynamic>? session,
    Duration? receiveTimeout,
  }) async => throw StateError('Capability gate must not call a service');
}

void main() {
  const blockedPaths = [
    '/me/settings/payment-security',
    '/me/settings/delete-account',
    '/me/assets',
    '/commerce/orders',
    '/commerce/orders/detail?orderRef=fixture',
    '/commerce/payment', // Deliberately no typed extra.
    '/club/aa',
    '/club/aa/positioning-card',
    '/club/parties',
    '/club/parties/create?date=2026-09-29',
    '/club/parties/manage',
    '/club/admission',
    '/commerce/ordering',
    '/commerce/ordering/confirm',
  ];
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('only live mode blocks demo business; real routes remain available', () {
    for (final path in blockedPaths) {
      expect(
        unavailableLiveFeature(Uri.parse(path), liveMode: true),
        isNotNull,
      );
      expect(unavailableLiveFeature(Uri.parse(path), liveMode: false), isNull);
    }
    for (final path in [
      '/home',
      '/me/settings',
      '/auth/mobile',
      '/messages/contacts',
      '/commerce/ordering?tableId=fixture-table',
      '/commerce/ordering/confirm',
    ]) {
      expect(
        unavailableLiveFeature(
          Uri.parse(path),
          liveMode: true,
          hasLiveOrderingContext: true,
        ),
        isNull,
      );
    }
  });

  for (final useRealRepository in [true, false]) {
    testWidgets(
      'real mode guards all demo routes before building: repository=$useRealRepository',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            if (useRealRepository)
              authRepositoryProvider.overrideWithValue(
                RealAuthRepository(_NoNetwork(), SecureSessionStore()),
              ),
          ],
        );
        addTearDown(container.dispose);
        if (!useRealRepository) {
          container
              .read(authenticatedMemberProvider.notifier)
              .update(
                const AuthLoginResult(
                  isNewMembership: false,
                  membershipStatus: 'active',
                  registrationStatus: 'approved',
                  isRealSession: true,
                ),
              );
        }
        final router = container.read(appRouterProvider);
        router.go(blockedPaths.first);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: KingTheme.dark,
              routerConfig: router,
            ),
          ),
        );
        for (final path in blockedPaths) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(
            find.byType(UnavailableFeaturePage),
            findsOneWidget,
            reason: path,
          );
          expect(
            router.routeInformationProvider.value.uri.path,
            '/feature-unavailable',
          );
          expect(tester.takeException(), isNull, reason: path);
        }
        // Pushed blocked destinations must still return to the prior route.
        router.go('/feature-unavailable?feature=orders');
        await tester.pumpAndSettle();
        router.push<void>('/me/settings/delete-account');
        await tester.pumpAndSettle();
        expect(router.canPop(), isTrue);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<UnavailableFeaturePage>(
                find.byType(UnavailableFeaturePage),
              )
              .feature,
          UnavailableLiveFeature.orders,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final locale in kingSupportedLocales) {
    testWidgets(
      'unavailable state supports $locale on a small large-text screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var returns = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: kingSupportedLocales,
            localizationsDelegates: kingLocalizationDelegates,
            theme: KingTheme.dark,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: UnavailableFeaturePage(
                feature: UnavailableLiveFeature.accountDeletion,
                onBack: () => returns++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        expect(returns, 1);
      },
    );
  }
}
