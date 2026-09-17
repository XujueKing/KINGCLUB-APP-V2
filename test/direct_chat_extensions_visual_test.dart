import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/core/design_system/king_components.dart';
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
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
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
    expect(tester.getSize(backImage), KingBackButton.glyphSize);
    expect(
      tester.getCenter(backButton).dy,
      closeTo(tester.getCenter(find.text('卡座搭子')).dy, 1),
    );
  });

  Future<void> loadPanelImages(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('two-row attachment pages retain the approved order', (
    tester,
  ) async {
    await pumpChat(tester);
    await tester.tap(find.byKey(const ValueKey('direct-chat-attachments')));
    await tester.pumpAndSettle();
    await loadPanelImages(tester);
    const first = [
      '\u7167\u7247',
      '\u62cd\u6444',
      '\u89c6\u9891\u901a\u8bdd',
      '\u4f4d\u7f6e',
    ];
    const second = [
      '\u91d1\u5e01',
      '\u7ea2\u5305',
      '\u793c\u7269',
      '\u8bed\u97f3\u8f93\u5165',
    ];
    for (final labels in [first, second]) {
      final centers = labels
          .map((label) => tester.getCenter(find.text(label)))
          .toList();
      for (var i = 1; i < centers.length; i++) {
        expect(centers[i].dy, closeTo(centers.first.dy, .1));
        expect(centers[i].dx, greaterThan(centers[i - 1].dx));
      }
    }
    expect(
      tester.getCenter(find.text(second.first)).dy,
      greaterThan(tester.getCenter(find.text(first.first)).dy),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/direct_chat_attachments_current_393x852.png'),
    );
    await tester.drag(
      find.byKey(const PageStorageKey('chat-attachment-pages')),
      const Offset(-350, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('\u6587\u4ef6').hitTestable(), findsOneWidget);
    expect(find.text('\u5361\u5238').hitTestable(), findsOneWidget);
    expect(find.text(first.first).hitTestable(), findsNothing);
  });

  testWidgets('gift panel opens from attachments and closes with plus', (
    tester,
  ) async {
    await pumpChat(tester);
    await tester.tap(find.byKey(const ValueKey('direct-chat-attachments')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\u793c\u7269'));
    await tester.pumpAndSettle();
    await loadPanelImages(tester);
    expect(
      find.byKey(const ValueKey('direct-chat-gift-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('direct-chat-attachment-panel')),
      findsNothing,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/direct_chat_gifts_current_393x852.png'),
    );
    await tester.tap(find.byKey(const ValueKey('direct-chat-attachments')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('direct-chat-gift-panel')), findsNothing);
    expect(
      find.byKey(const ValueKey('direct-chat-attachment-panel')),
      findsOneWidget,
    );
  });
}
