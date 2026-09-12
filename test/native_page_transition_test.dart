import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/profile_settings/presentation/settings_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/personal_qr_page.dart';

void main() {
  for (final page in <Widget>[const SettingsPage(), const PersonalQrPage()]) {
    testWidgets('${page.runtimeType} animates push and pop', (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: KingTheme.dark.copyWith(platform: TargetPlatform.android),
          navigatorKey: key,
          home: const Scaffold(body: Text('home')),
        ),
      );
      final route = MaterialPageRoute<void>(builder: (_) => page);
      key.currentState!.push(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(route.animation!.value, greaterThan(0));
      expect(route.animation!.value, lessThan(1));
      expect(tester.widgetList<SlideTransition>(find.byType(SlideTransition)).any((w)=>w.position.value.dx>0&&w.position.value.dx<1),isTrue);
      await tester.pump(const Duration(seconds: 1));
      key.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(route.animation!.value, greaterThan(0));
      expect(route.animation!.value, lessThan(1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
