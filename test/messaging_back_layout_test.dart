import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_components.dart';
import 'package:kingclub/src/features/messaging/presentation/legacy_messaging_components.dart';

void main() {
  for (final width in [360.0, 393.0, 430.0]) {
    testWidgets('chat back matches registration at $width', (tester) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var pressed = false;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: LegacyMessagingHeader(title: '聊天', onBack: () => pressed = true))));
      final button = find.byKey(const ValueKey('messaging-back'));
      expect(tester.getTopLeft(button).dx, closeTo(width * .1 - 20, .001));
      expect(tester.getTopLeft(button).dy, 4);
      expect(tester.getSize(button), const Size(48, 48));
      final glyph = find.descendant(of: button, matching: find.byType(Image));
      expect(tester.getSize(glyph), KingBackButton.glyphSize);
      await tester.tap(button);
      expect(pressed, isTrue);
    });
  }
}
