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
    await tester.tap(find.byKey(const ValueKey('direct-chat-gifts')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/direct_chat_gifts_393x852.png'),
    );
  });
}
