import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_components.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/messaging/presentation/legacy_messaging_components.dart';
import 'package:kingclub/src/features/onboarding/presentation/onboarding_components.dart';
import 'package:kingclub/src/features/scanner/presentation/safe_scanner_page.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';

void main() {
  for (final width in [320.0, 393.0, 430.0]) {
    testWidgets(
      'registration, chat, scanner and ordering share back geometry $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 852);
        tester.view.padding = const FakeViewPadding(top: 24);
        addTearDown(tester.view.reset);
        var presses = 0;
        final pages = <Widget>[
          OnboardingScaffold(
            step: 1,
            title: 'Test',
            subtitle: '',
            onBack: () => presses++,
            child: const SizedBox(),
          ),
          Scaffold(
            body: SafeArea(
              child: LegacyMessagingHeader(
                title: 'Chat',
                alignToConversationTitle: true,
                onBack: () => presses++,
              ),
            ),
          ),
          SafeScannerPage(onClose: () => presses++, onResolved: (_) {}),
          ScanOrderingCartPage(onBack: () => presses++),
        ];
        Rect? reference;
        for (final page in pages) {
          await tester.pumpWidget(
            MaterialApp(theme: KingTheme.dark, home: page),
          );
          await tester.pumpAndSettle();
          final back = find.byType(KingBackButton);
          final rect = tester.getRect(back);
          reference ??= rect;
          expect(rect, reference);
          expect(rect.size, const Size(48, 48));
          final glyph = find.descendant(of: back, matching: find.byType(Image));
          // Original chat had x=-2 + 20dp glyph inset, y=safeArea+4+16.
          expect(tester.getTopLeft(glyph), const Offset(18, 44));
          await tester.tap(back);
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        expect(presses, pages.length);
      },
    );
  }

  testWidgets('shared app bar preserves automatic route return', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: kingAppBar(
                      context: context,
                      title: const Text('Inner'),
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(KingBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Inner'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
}
