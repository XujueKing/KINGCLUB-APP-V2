import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/presentation/together_activity_action.dart';
import 'package:kingclub/src/features/club/presentation/together_play_page.dart';

import 'together_play_test.dart' show fixture;

void main() {
  test(
    'warm, icy and brown footers choose their own action and text colors',
    () {
      final orange = TogetherFooterPalette(const Color(0xFFE98F23));
      final ice = TogetherFooterPalette(const Color(0xFFD6DDE5));
      final brown = TogetherFooterPalette(const Color(0xFF40392F));
      expect(orange.primary, Colors.white);
      expect(brown.primary, Colors.white);
      expect(ice.primary.computeLuminance(), lessThan(.02));
      expect(
        orange.action.computeLuminance(),
        greaterThan(const Color(0xFFE98F23).computeLuminance()),
      );
      expect(
        brown.action.computeLuminance(),
        greaterThan(const Color(0xFF40392F).computeLuminance()),
      );
      expect(ice.action.computeLuminance(), lessThan(.25));
      for (final palette in [orange, ice, brown]) {
        expect(palette.actionText, Colors.white);
      }
    },
  );

  testWidgets('native-sized flat pill keeps a larger touch target and gating', (
    tester,
  ) async {
    var taps = 0;
    Future<void> mount(bool enabled) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: Center(
            child: TogetherActivityAction(
              palette: TogetherFooterPalette(const Color(0xFFD6DDE5)),
              label: '加入',
              onPressed: enabled ? () => taps++ : null,
            ),
          ),
        ),
      ),
    );
    await mount(false);
    final button = find.byType(TextButton);
    final pill = find.byKey(const ValueKey('together-action-pill'));
    expect(tester.getSize(pill), const Size(74, 32));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    expect(find.byType(BackdropFilter), findsNothing);
    final textStyle = tester
        .widget<TextButton>(button)
        .style!
        .textStyle!
        .resolve({})!;
    expect(textStyle.fontSize, 17);
    expect(textStyle.fontWeight, FontWeight.w600);
    expect(textStyle.fontFamily, 'CupertinoSystemText');
    await tester.tap(button);
    expect(taps, 0);
    await mount(true);
    await tester.tap(button);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'merchant footer icon and type stay fixed from card to full width',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [353.0, 402.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: Scaffold(
              body: SingleChildScrollView(
                child: TogetherAvailableRow(
                  party: fixture(),
                  edgeInset: false,
                  showHeading: false,
                  showAction: true,
                  blurFooter: false,
                  onTap: () {},
                  onAction: () {},
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(
            find.byKey(const ValueKey('together-summary-icon-night')),
          ),
          const Size(48, 48),
        );
        final title = tester.widget<Text>(
          find.byKey(const ValueKey('together-summary-title-night')),
        );
        final subtitle = tester.widget<Text>(
          find.byKey(const ValueKey('together-summary-subtitle-night')),
        );
        expect(title.style!.fontSize, 16);
        expect(subtitle.style!.fontSize, 13);
        expect(title.style!.fontFamily, 'CupertinoSystemText');
        expect(
          tester.getSize(find.byKey(const ValueKey('together-action-pill'))),
          const Size(74, 32),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
