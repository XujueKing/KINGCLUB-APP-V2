import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/chat_text_draft_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, ack, history;

class DelayedReadStore extends ChatTextDraftStore {
  DelayedReadStore() : super('me', 'peer:peer', () async {});
  final restored = Completer<ChatTextDraft?>();
  @override
  Future<ChatTextDraft?> read() => restored.future;
}

class DelayedOutbox extends MemoryOutbox {
  final ready = Completer<void>();
  @override
  Future<void> put(Map<String, dynamic> message) async {
    await ready.future;
    await super.put(message);
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  final input = find.byKey(const ValueKey('direct-chat-input'));
  Future<void> open(
    WidgetTester tester,
    ChatTextDraftStore store, {
    MemoryOutbox? outbox,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DirectChatPage(
          peerAccount: 'peer',
          chatOutbox: outbox ?? MemoryOutbox(),
          openTextDraftStore: (account, target) async {
            expect(account, 'me');
            expect(target, 'peer:peer');
            return store;
          },
          repository: MessagingRepository(
            account: 'me',
            call: (id, params) async {
              if (id == 'K260913000604') return history([]);
              if (id == 'K260913000601') return {'message': ack(params)};
              return <String, dynamic>{};
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final delayed in [false, true]) {
    testWidgets(
      'deleted draft quote is removed, preserves input delayed=$delayed',
      (tester) async {
        final store = delayed
            ? DelayedReadStore()
            : ChatTextDraftStore('me', 'peer:peer', () async {});
        final draft = ChatTextDraft(
          'unfinished',
          replyTo: '11111111-1111-4111-8111-111111111111',
          preview: 'deleted quote',
        );
        if (!delayed) await store.write(draft);
        await open(tester, store);
        await ChatMediaDeletion('other', false, draft.replyTo!).dispatch();
        await ChatMediaDeletion('me', true, draft.replyTo!).dispatch();
        await tester.pump();
        if (!delayed) expect(find.text('deleted quote'), findsOneWidget);
        await ChatMediaDeletion('me', false, draft.replyTo!).dispatch();
        if (delayed) (store as DelayedReadStore).restored.complete(draft);
        await tester.pumpAndSettle();
        expect(find.text('deleted quote'), findsNothing);
        expect(tester.widget<TextField>(input).controller!.text, 'unfinished');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final saved = await ChatTextDraftStore(
          'me',
          'peer:peer',
          () async {},
        ).read();
        expect(saved!.text, 'unfinished');
        expect(saved.replyTo, isNull);
        expect(saved.preview, isNull);
        await ChatMediaDeletion('me', false, draft.replyTo!).dispatch();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('restores text and quote, persists quote removal on leaving', (
    tester,
  ) async {
    final store = ChatTextDraftStore('me', 'peer:peer', () async {});
    await store.write(
      ChatTextDraft(
        'unfinished',
        replyTo: '11111111-1111-4111-8111-111111111111',
        preview: 'quoted',
      ),
    );
    await open(tester, store);
    expect(tester.widget<TextField>(input).controller!.text, 'unfinished');
    expect(find.text('quoted'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('direct-chat-close-quote')));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final saved = await store.read();
    expect(saved!.text, 'unfinished');
    expect(saved.replyTo, isNull);
    expect(saved.preview, isNull);
  });

  testWidgets('late restore does not overwrite new input', (tester) async {
    final store = DelayedReadStore();
    await open(tester, store);
    await tester.enterText(input, 'new input');
    store.restored.complete(ChatTextDraft('old input'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, 'new input');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(
      (await ChatTextDraftStore('me', 'peer:peer', () async {}).read())!.text,
      'new input',
    );
  });

  testWidgets(
    'queue acknowledgement preserves text typed while persistence pending',
    (tester) async {
      final store = ChatTextDraftStore('me', 'peer:peer', () async {});
      final outbox = DelayedOutbox();
      await open(tester, store, outbox: outbox);
      await tester.enterText(input, 'first');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      await tester.enterText(input, 'next');
      await tester.pump(const Duration(milliseconds: 350));
      outbox.ready.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, 'next');
      expect((await store.read())!.text, 'next');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed queue write keeps draft; successful retry clears it', (
    tester,
  ) async {
    final store = ChatTextDraftStore('me', 'peer:peer', () async {});
    final outbox = MemoryOutbox()..failWrite = true;
    await open(tester, store, outbox: outbox);
    await tester.enterText(input, 'keep until queued');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(input).controller!.text,
      'keep until queued',
    );
    final original = await store.read();
    expect(original!.text, 'keep until queued');
    expect(outbox.items, isEmpty);
    outbox.failWrite = false;
    await tester.showKeyboard(input);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    expect(await store.read(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
