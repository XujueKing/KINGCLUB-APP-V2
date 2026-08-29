import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/shell/presentation/app_shell_page.dart';

void main() {
  testWidgets('legacy home visual baseline', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: KingTheme.dark,
        home: AppShellPage(
          onOpenTogether: () {},
          onOpenParty: () {},
          onOpenScanner: (_, _) async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppShellPage),
      matchesGoldenFile('goldens/home_legacy_393x852.png'),
    );
  });
}
