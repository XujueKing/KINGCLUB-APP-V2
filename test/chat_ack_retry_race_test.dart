import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox.dart';
import 'package:kingclub/src/features/messaging/data/chat_session_controller.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

import 'direct_chat_controller_test.dart' as direct;
import 'group_chat_controller_test.dart' as group;

class _Outbox implements ChatOutbox {
  final rows = <String, Map<String, dynamic>>{};
  final writingFailure = Completer<void>(), releaseFailure = Completer<void>();
  @override
  Future<List<Map<String, dynamic>>> read() async => rows.values.toList();
  @override
  Future<void> put(Map<String, dynamic> row) async {
    rows[row['clientMessageId'] as String] = {...row};
    if (row.containsKey('error')) {
      if (!writingFailure.isCompleted) writingFailure.complete();
      await releaseFailure.future;
    }
  }

  @override
  Future<void> remove(String id) async => rows.remove(id);
}

void main() {
  for (final isGroup in [false, true]) {
    test(
      '${isGroup ? "group" : "direct"} history ACK wins over late failure persistence',
      () async {
        final outbox = _Outbox();
        Map<String, dynamic>? sent;
        var sends = 0;
        final repo = MessagingRepository(
          account: 'me',
          call: (id, params) async {
            if (id == 'K260913000601' || id == 'K260913000620') {
              sends++;
              sent = params;
              throw const AuthFailure('NETWORK_ERROR', 'lost response');
            }
            if (id == 'K260913000619') return {'members': []};
            final messages = sent == null
                ? <Map<String, dynamic>>[]
                : [
                    isGroup
                        ? group.message(sent!['clientMessageId'] as String)
                        : direct.ack(sent!),
                  ];
            return isGroup ? group.history(messages) : direct.history(messages);
          },
        );
        final ChatSessionController chat = isGroup
            ? GroupChatController(
                repository: GroupChatRepository(repo),
                groupId: 'group',
                outbox: outbox,
              )
            : DirectChatController(
                repository: repo,
                peer: 'peer',
                outbox: outbox,
              );
        await chat.initialize();
        final sending = chat.send('hello');
        await outbox.writingFailure.future;
        await chat.synchronize();
        expect(chat.messages.single['status'], 'sent');
        outbox.releaseFailure.complete();
        await sending;
        await chat.retryQueued();
        expect(outbox.rows, isEmpty);
        expect(sends, 1);
        expect(chat.error, isNull);
        chat.dispose();
      },
    );
  }
}
