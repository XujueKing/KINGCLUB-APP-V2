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
    expect(tester.widget<ListView>(list).reverse, isTrue);
    expect(controller.position.pixels, 0);
    expect(find.text('History 29').hitTestable(), findsOneWidget);
    expect(find.text('History 0').hitTestable(), findsNothing);
    controller.jumpTo(controller.position.maxScrollExtent / 2);
    await tester.pumpAndSettle();
    expect(controller.position.extentBefore, greaterThan(100));
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
    await tester.pump();
    for (
      var frame = 0;
      frame < 30 && find.text('New outgoing message').evaluate().isEmpty;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final enteringTextSize = tester.getSize(find.text('New outgoing message'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.text('New outgoing message')), enteringTextSize);
    expect(find.text('New outgoing message').hitTestable(), findsOneWidget);
    expect(controller.position.extentBefore, lessThan(48));
    await tester.pumpWidget(const SizedBox());
  });
}
