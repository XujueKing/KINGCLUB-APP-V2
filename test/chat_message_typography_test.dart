import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, ack, history;

Finder bubbleFor(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) {
    if (widget is! DecoratedBox) return false;
    final decoration = widget.decoration;
    return decoration is BoxDecoration &&
        (decoration.color == const Color(0xFF27B561) ||
            decoration.color == const Color(0xFF2C2C2C));
  }),
);

Future<void> openChat(
  WidgetTester tester,
  List<String> messages, {
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 852);
  addTearDown(tester.view.reset);
  final repo = MessagingRepository(
    account: 'me',
    call: (method, params) async {
      if (method != 'K260913000604') return {};
      return history([
        for (var i = 0; i < messages.length; i++)
          {
            ...ack({
              'clientMessageId': 'typography-$i',
              'text': messages[i],
            }, sequence: i + 1),
            'sender': i.isEven ? 'me' : 'peer',
            'recipient': i.isEven ? 'peer' : 'me',
          },
      ]);
    },
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: KingTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: DirectChatPage(
        peerAccount: 'peer',
        peerName: 'Test peer',
        repository: repo,
        chatOutbox: MemoryOutbox(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'single-line emoji and text bubbles have equal height on both sides',
    (tester) async {
      const messages = ['中文 Hello', '你好 World', '😀', '😊👍'];
      await openChat(tester, messages);
      final heights = [
        for (final text in messages) tester.getSize(bubbleFor(text)).height,
      ];
      expect(heights.first, closeTo(42, 0.1));
      for (final height in heights.skip(1)) {
        expect(height, closeTo(heights.first, 0.1));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'long text wraps within the bubble and respects larger system text',
    (tester) async {
      const text = '聊天中文与 English 文字需要正常换行，不裁切，也不超出屏幕。';
      await openChat(tester, [text]);
      final originalHeight = tester.getSize(bubbleFor(text)).height;
      expect(originalHeight, greaterThan(42));
      await tester.pumpWidget(const SizedBox());
      await openChat(tester, [text], scale: 1.5);
      final bubble = tester.getRect(bubbleFor(text));
      final content = tester.getRect(find.text(text));
      expect(bubble.height, greaterThan(originalHeight));
      expect(content.left, greaterThanOrEqualTo(bubble.left));
      expect(content.right, lessThanOrEqualTo(bubble.right));
      expect(content.top, greaterThanOrEqualTo(bubble.top));
      expect(content.bottom, lessThanOrEqualTo(bubble.bottom));
      expect(bubble.left, greaterThanOrEqualTo(0));
      expect(bubble.right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
