import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_components.dart';
import 'package:kingclub/src/features/messaging/presentation/legacy_messaging_components.dart';

void main() {
  testWidgets('conversation controls are equidistant from title', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LegacyMessagingHeader(
            title: 'A conversation',
            alignToConversationTitle: true,
            onBack: () {},
            trailing: IconButton(
              key: const ValueKey('more'),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              padding: EdgeInsets.zero,
              onPressed: () {},
              icon: const Icon(Icons.more_horiz, size: 24),
            ),
          ),
        ),
      ),
    );
    final left = tester.getCenter(find.byKey(const ValueKey('messaging-back')));
    final right = tester.getCenter(find.byKey(const ValueKey('more')));
    final title = tester.getCenter(find.text('A conversation'));
    expect(title.dx - left.dx, closeTo(right.dx - title.dx, .001));
    expect(left.dy, right.dy);
  });
  for (final width in [360.0, 393.0, 430.0]) {
    testWidgets(
      'back preserves original conversation glyph position at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var pressed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LegacyMessagingHeader(
                title: '聊天',
                onBack: () => pressed = true,
              ),
            ),
          ),
        );
        final button = find.byKey(const ValueKey('messaging-back'));
        expect(tester.getTopLeft(button).dx, 0);
        expect(tester.getTopLeft(button).dy, 4);
        expect(tester.getSize(button), const Size(48, 48));
        final glyph = find.descendant(of: button, matching: find.byType(Image));
        expect(tester.getSize(glyph), KingBackButton.glyphSize);
        expect(tester.getTopLeft(glyph), const Offset(18, 20));
        await tester.tap(button);
        expect(pressed, isTrue);
      },
    );
  }
}
