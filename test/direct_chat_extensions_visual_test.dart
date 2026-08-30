import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

void main() {
  Future<void> pumpChat(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: KingTheme.dark,
        home: const DirectChatPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chat back control uses the global size and title alignment', (
    tester,
  ) async {
    await pumpChat(tester);

    final backButton = find.byKey(const ValueKey('messaging-back'));
    final backImage = find.descendant(
      of: backButton,
      matching: find.byType(Image),
    );

    expect(tester.getSize(backButton), const Size(48, 48));
    expect(tester.getSize(backImage), const Size(11, 22));
    expect(
      tester.getCenter(backButton).dy,
      closeTo(tester.getCenter(find.text('卡座搭子')).dy, 0.01),
    );
  });

  testWidgets('legacy attachment panel visual', (tester) async {
    await pumpChat(tester);
    await tester.tap(find.byKey(const ValueKey('direct-chat-attachments')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/direct_chat_attachments_393x852.png'),
    );
  });

  testWidgets('legacy gift panel visual', (tester) async {
    await pumpChat(tester);
    expect(
      find.byKey(const ValueKey('direct-chat-gifts-icon-inactive')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('direct-chat-gifts')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('direct-chat-gifts-icon-active')),
      findsOneWidget,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/direct_chat_gifts_393x852.png'),
    );

    await tester.tap(find.byKey(const ValueKey('direct-chat-gifts')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('direct-chat-gifts-icon-inactive')),
      findsOneWidget,
    );
  });
}
