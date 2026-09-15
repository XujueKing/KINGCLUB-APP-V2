import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_draft_store.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_file_send_page.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, ack;

class Drafts extends ChatFileDraftStore {
  Drafts()
    : super(account: 'me', target: 'direct:peer', checkSession: () async {});
  final removed = <String>[];
  @override
  Future<void> remove(String id) async {
    removed.add(id);
  }
}

void main() {
  for (final confirmed in [false, true]) {
    testWidgets('file draft already owned by chat skips upload: $confirmed', (
      tester,
    ) async {
      const id = '33333333-3333-4333-8333-333333333333';
      const asset = '12345678-1234-1234-1234-123456789012';
      var calls = 0;
      final queue = MemoryOutbox();
      final chat = DirectChatController(
        peer: 'peer',
        outbox: queue,
        repository: MessagingRepository(
          account: 'me',
          call: (_, params) async {
            calls++;
            if (!confirmed) throw const AuthFailure('NETWORK_ERROR', 'offline');
            return {
              'message': {
                ...ack(params),
                'messageType': 'file',
                'fileAssetId': asset,
                'fileName': 'fixture.bin',
                'fileSize': 2,
                'fileSha256': 'a' * 64,
                'text': '[文件]',
              },
            };
          },
        ),
      );
      addTearDown(chat.dispose);
      await chat.sendFile(
        asset,
        'fixture.bin',
        2,
        'a' * 64,
        clientMessageId: id,
      );
      final drafts = Drafts();
      final file = File('/not-needed-for-already-queued.bin');
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ChatFileSendPage(
                      file: file,
                      fileName: 'fixture.bin',
                      chat: chat,
                      drafts: drafts,
                      draft: ChatFileDraft(
                        id,
                        file,
                        'fixture.bin',
                        2,
                        'a' * 64,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('发送'));
      await tester.pumpAndSettle();
      expect(result, true);
      expect(drafts.removed, [id]);
      expect(calls, 1);
      expect(chat.messages, hasLength(1));
      expect(queue.items, confirmed ? isEmpty : hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
}
