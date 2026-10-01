import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, ack, history;

void main() {
  testWidgets('IME frames move composer and latest message together', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    var historyReads = 0;
    final repo = MessagingRepository(
      account: 'me',
      call: (method, params) async {
        if (method == 'K260913000604') {
          historyReads++;
          return history(
            List.generate(
              30,
              (i) => ack({
                'clientMessageId': 'ime-$i',
                'text': 'Keyboard history $i',
              }, sequence: i + 1),
            ),
          );
        }
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
    final latest = find.text('Keyboard history 29');
    final composer = find.byType(TextField);
    final initialComposerY = tester.getTopLeft(composer).dy;
    final initialMessageY = tester.getTopLeft(latest).dy;
    final textSize = tester.getSize(latest);
    final initialReads = historyReads;
    final list = tester.widget<ListView>(find.byType(ListView).first);
    for (final inset in <double>[24, 72, 144, 228, 300, 228, 144, 72, 24, 0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.getTopLeft(composer).dy,
        closeTo(initialComposerY - inset, 0.1),
      );
      expect(
        tester.getTopLeft(latest).dy,
        closeTo(initialMessageY - inset, 0.1),
      );
      expect(tester.getSize(latest), textSize);
      expect(list.controller!.position.pixels, closeTo(0, 0.1));
      expect(historyReads, initialReads);
      expect(tester.takeException(), isNull);
    }
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getTopLeft(composer).dy, initialComposerY);
    expect(tester.getTopLeft(latest).dy, initialMessageY);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'focus does not lift history for a transient navigation inset before IME',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: DirectChatPage(peerName: 'Test peer')),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('direct-chat-input'));
      final initialY = tester.getTopLeft(input).dy;
      await tester.tap(input);
      await tester.pump();
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getTopLeft(input).dy, closeTo(initialY, .1));
      for (final inset in <double>[24, 72, 144, 228, 300]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getTopLeft(input).dy, closeTo(initialY - inset, .1));
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('first outgoing bubble slides up without changing text size', (
    tester,
  ) async {
    final send = Completer<Map<String, dynamic>>();
    final repo = MessagingRepository(
      account: 'me',
      call: (method, params) async {
        if (method == 'K260913000604') return history([]);
        if (method == 'K260913000601') return send.future;
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
    await tester.enterText(find.byType(TextField), 'First message');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.pump(const Duration(milliseconds: 40));
    final text = find.text('First message');
    final size = tester.getSize(text);
    final enteringY = tester.getTopLeft(text).dy;
    await tester.pump(const Duration(milliseconds: 70));
    expect(tester.getTopLeft(text).dy, lessThan(enteringY));
    expect(tester.getSize(text), size);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getSize(text), size);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    send.complete({});
    await tester.pump();
  });

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
    await tester.testTextInput.receiveAction(TextInputAction.send);
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
