import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, ack, history;

void main() {
  testWidgets('sending from older history reveals the newly queued message', (
    tester,
  ) async {
    final rows = List.generate(
      30,
      (i) => ack({
        'clientMessageId': 'old-$i',
        'text': 'History $i',
      }, sequence: i + 1),
    );
    final repo = MessagingRepository(
      account: 'me',
      call: (method, params) async {
        if (method == 'K260913000604') return history(rows);
        if (method == 'K260913000601') throw StateError('offline');
        return {};
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DirectChatPage(
          peerAccount: 'peer',
          peerName: 'Test peer',
          repository: repo,
          chatOutbox: MemoryOutbox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = find.byType(ListView).first;
    final controller = tester.widget<ListView>(list).controller!;
    controller.jumpTo(controller.position.maxScrollExtent / 2);
    await tester.pumpAndSettle();
    expect(controller.position.extentAfter, greaterThan(100));
    final readingOffset = controller.position.pixels;
    rows.add({
      ...ack({
        'clientMessageId': 'incoming',
        'text': 'New incoming message',
      }, sequence: 31),
      'sender': 'peer',
      'recipient': 'me',
    });
    await repo.settings('peer', remark: 'Test peer');
    await tester.pumpAndSettle();
    expect(controller.position.pixels, closeTo(readingOffset, 1));
    await tester.enterText(find.byType(TextField), 'New outgoing message');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('direct-chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('New outgoing message').hitTestable(), findsOneWidget);
    expect(controller.position.extentAfter, lessThan(48));
    await tester.pumpWidget(const SizedBox());
  });
}
