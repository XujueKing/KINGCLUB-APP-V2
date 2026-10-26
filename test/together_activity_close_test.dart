import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/presentation/together_activity_close.dart';
import 'package:kingclub/src/features/club/presentation/together_glass.dart';

import 'together_artwork_contrast_test.dart' as artwork;

void main() {
  testWidgets(
    'glass action keeps disabled gating and an enabled purchase tap',
    (tester) async {
      var joins = 0;
      Future<void> mount(bool enabled) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TogetherGlassAction(
                ink: TogetherGlassInk(const Color(0xFFF5F48B)),
                label: '加入',
                onPressed: enabled ? () => joins++ : null,
                minimumSize: const Size(72, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ),
      );
      await mount(false);
      await tester.tap(find.text('加入'));
      expect(joins, 0);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).enabled,
        isFalse,
      );
      expect(
        tester.getSize(find.byType(TextButton)).height,
        greaterThanOrEqualTo(44),
      );
      await mount(true);
      await tester.tap(find.text('加入'));
      expect(joins, 1);
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'glass tint and X contrast adapt to bright yellow and blue backgrounds',
    () {
      for (final background in [
        const Color(0xFFF5F48B),
        const Color(0xFF8FB3C6),
        const Color(0xFF1C1C1E),
      ]) {
        final ink = TogetherCloseInk(background);
        final surface = Color.alphaBlend(ink.surface, background);
        final foreground = Color.alphaBlend(ink.foreground, surface);
        final a = surface.computeLuminance(), b = foreground.computeLuminance();
        expect(
          ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05),
          greaterThan(4.5),
        );
        expect(ink.surface.a, closeTo(.72, .001));
        expect(
          ink.foreground.computeLuminance() < .1,
          background.computeLuminance() > .65,
        );
      }
    },
  );

  test('close button samples its own corner rather than the title region', () {
    final sample = artwork.sample(
      64,
      64,
      (x, y) =>
          x >= 40 && y < 20 ? const Color(0xFFF5F48B) : const Color(0xFF8FB3C6),
    );
    expect(
      sample.colorInRegion(1, const Rect.fromLTWH(.7, .1, .2, .2)),
      const Color(0xFFF5F48B),
    );
    expect(
      sample.colorInRegion(1, const Rect.fromLTWH(.7, .7, .2, .2)),
      const Color(0xFF8FB3C6),
    );
  });

  testWidgets(
    '44px close control blurs only after flight and remains tappable',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var closes = 0;
      final card = GlobalKey();
      Future<void> mount(double progress) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TogetherActivityClose(
                source: null,
                scroll: scroll,
                motion: AlwaysStoppedAnimation(progress),
                cardKey: card,
                onPressed: () => closes++,
              ),
            ),
          ),
        ),
      );
      await mount(.5);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        isFalse,
      );
      await mount(1);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        isTrue,
      );
      final button = find.byKey(const ValueKey('together-close-detail'));
      expect(tester.getSize(button), const Size(44, 44));
      await tester.tap(button);
      expect(closes, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
