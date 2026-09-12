import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/navigation/app_router.dart';
import 'package:kingclub/src/features/profile_settings/presentation/settings_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/personal_qr_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/about_legal_page.dart';

void main() {
  testWidgets('generated routes slide through settings, its child, and QR', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        $settingsRoute,
        $personalQrRoute,
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: KingTheme.dark.copyWith(platform: TargetPlatform.android),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> checkSlide(Type type, {bool returning = false}) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final finder = find.byType(type);
      final route = ModalRoute.of(tester.element(finder))! as PageRoute;
      expect(route.transitionDuration, const Duration(milliseconds: 240));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 220),
      );
      expect(route.animation!.value, inExclusiveRange(0, 1));
      final slides = tester.widgetList<SlideTransition>(
        find.ancestor(of: finder, matching: find.byType(SlideTransition)),
      );
      expect(
        slides.any((s) => s.position.value.dx > 0 && s.position.value.dx < 1),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    router.push('/me/settings');
    await checkSlide(SettingsPage);
    await tester.tap(find.text('关于 KINGCLUB'));
    await checkSlide(AboutLegalPage);
    router.pop();
    await checkSlide(AboutLegalPage, returning: true);
    expect(find.byType(SettingsPage), findsOneWidget);
    router.pop();
    await checkSlide(SettingsPage, returning: true);
    router.push('/me/qr');
    await checkSlide(PersonalQrPage);
    router.pop();
    await checkSlide(PersonalQrPage, returning: true);
    expect(find.text('home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}
