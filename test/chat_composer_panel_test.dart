import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

void main() {
  testWidgets('hold overlay highlights cancel and dismisses on release', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('direct-chat-microphone')));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('direct-chat-hold-to-talk'))),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('松手发送'), findsOneWidget);
    await gesture.moveBy(const Offset(-100, -100));
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('松开取消'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('松开取消'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('microphone expands and returns to text without losing draft', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()),
    );
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('direct-chat-input'));
    await tester.enterText(input, 'draft');
    await tester.tap(find.byKey(const ValueKey('direct-chat-microphone')));
    await tester.pump();
    final surface = find.byKey(const ValueKey('direct-chat-voice-surface'));
    final initialWidth = tester.getSize(surface).width;
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getSize(surface).width, greaterThan(initialWidth));
    await tester.pumpAndSettle();
    expect(find.text('按住 说话'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('direct-chat-text-mode')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, 'draft');
    expect(tester.takeException(), isNull);
  });
  testWidgets('composer opens emoji picker and inserts selected emoji', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('direct-chat-emoji')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('direct-chat-emoji-panel')),
      findsOneWidget,
    );
    await tester.tap(find.text('😀').last);
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('direct-chat-input')),
    );
    expect(field.controller!.text, '😀');
    await tester.tap(find.byTooltip('删除表情'));
    await tester.pump();
    expect(field.controller!.text, '');
    await tester.tap(find.byKey(const ValueKey('direct-chat-attachments')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('direct-chat-emoji-panel')), findsNothing);
    expect(
      find.byKey(const ValueKey('direct-chat-attachment-panel')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'attachments paginate after eight and blank tap closes panel and keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('direct-chat-attachments')));
      await tester.pumpAndSettle();
      expect(find.text('照片').hitTestable(), findsOneWidget);
      expect(find.text('语音输入').hitTestable(), findsOneWidget);
      expect(find.text('文件').hitTestable(), findsNothing);
      await tester.drag(
        find.byKey(const PageStorageKey('chat-attachment-pages')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('文件').hitTestable(), findsOneWidget);
      expect(find.text('卡券').hitTestable(), findsOneWidget);
      final blank = find.byKey(const ValueKey('direct-chat-dismiss-area'));
      await tester.tapAt(tester.getTopLeft(blank) + const Offset(4, 30));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('direct-chat-attachment-panel')),
        findsNothing,
      );
      final input = find.byKey(const ValueKey('direct-chat-input'));
      await tester.tap(input);
      await tester.pump();
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      await tester.tapAt(tester.getTopLeft(blank) + const Offset(4, 30));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'latest messages move with panel on intermediate frames and keyboard resize',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('direct-chat-input'));
      for (var i = 0; i < 8; i++) {
        await tester.enterText(input, 'message $i');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pumpAndSettle();
      }
      final list = find.byKey(const ValueKey('direct-chat-message-list'));
      final controller = tester.widget<ListView>(list).controller!;
      await tester.tap(find.byKey(const ValueKey('direct-chat-attachments')));
      await tester.pump();
      final initialHeight = tester.getSize(list).height;
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getSize(list).height, lessThan(initialHeight));
      expect(controller.position.extentAfter, lessThan(1));
      expect(
        tester.getBottomLeft(list).dy,
        lessThanOrEqualTo(
          tester
              .getTopLeft(find.byKey(const ValueKey('direct-chat-bottom-card')))
              .dy,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getTopLeft(list) + const Offset(3, 20));
      await tester.pumpAndSettle();
      await tester.tap(input);
      await tester.pump();
      for (final inset in [80.0, 160.0, 240.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pump();
        expect(controller.position.extentAfter, lessThan(1));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'emoji categories page horizontally and include local sticker entry',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('direct-chat-emoji')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('动物'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🐱').last);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('direct-chat-input')))
            .controller!
            .text,
        '🐱',
      );
      await tester.drag(
        find.byKey(const ValueKey('emoji-pages-1')),
        const Offset(-320, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find
            .descendant(
              of: find.byKey(const ValueKey('emoji-pages-1')),
              matching: find.text('🐱'),
            )
            .hitTestable(),
        findsNothing,
      );
      await tester.tap(find.byTooltip('添加的单个表情'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('add-single-sticker')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byTooltip('添加表情包').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
