import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_uploader.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_file_send_page.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox;

void main() {
  for (final opening in [false, true]) {
    testWidgets('session change blocks file send while opening=$opening', (
      tester,
    ) async {
      var calls = 0;
      final queue = MemoryOutbox();
      final repository = MessagingRepository(
        account: 'me',
        call: (_, _) async {
          calls++;
          throw StateError('no network work expected');
        },
      );
      final chat = DirectChatController(
        peer: 'peer',
        outbox: queue,
        repository: repository,
      );
      addTearDown(chat.dispose);
      final pending = Completer<ChatFileUploader>();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatFileSendPage(
            file: File('/unused-private-file'),
            fileName: 'private-name.txt',
            chat: chat,
            createUploader: () => pending.future,
          ),
        ),
      );
      if (opening) {
        await tester.tap(find.text('发送'));
        await tester.pump();
      }
      SecureSessionStore.changes.add(null);
      await tester.pump();
      expect(find.text('private-name.txt'), findsNothing);
      expect(find.text('登录状态已变化，请重新进入会话'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      if (opening) {
        pending.complete(
          ChatFileUploader(repository: repository, checkSession: () async {}),
        );
        await tester.pumpAndSettle();
      }
      expect(calls, 0);
      expect(queue.items, isEmpty);
      expect(find.text('登录状态已变化，请重新进入会话'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
