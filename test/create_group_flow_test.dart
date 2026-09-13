import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/create_group_page.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

import 'group_chat_controller_test.dart' show Queue;

void main() {
  testWidgets(
    'real selected friends create a group only after acknowledgement and send through group API',
    (tester) async {
      final created = Completer<Map<String, dynamic>>();
      final queue = Queue();
      Map<String, dynamic>? createRequest, sendRequest;
      final repo = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          switch (id) {
            case 'K260913000608':
              return {
                'items': [
                  {
                    'peer': 'actual-peer',
                    'nickname': 'Actual friend',
                    'bio': '',
                  },
                ],
                'hasMore': false,
              };
            case 'K260913000617':
              createRequest = params;
              return created.future;
            case 'K260913000621':
              return {
                'messages': [],
                'readSequence': 0,
                'lastSequence': 0,
                'hasMore': false,
              };
            case 'K260913000622':
              return {'readSequence': params['sequence']};
            case 'K260913000620':
              sendRequest = params;
              return {
                'message': {
                  'messageId': 'actual-message',
                  'groupId': 'actual-group',
                  'sender': 'me',
                  'clientMessageId': params['clientMessageId'],
                  'text': params['text'],
                  'sequence': 1,
                  'createdDate': '2026-09-13T01:00:00Z',
                },
              };
            default:
              throw StateError('Unexpected interface $id');
          }
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CreateGroupPage(
            repository: GroupChatRepository(repo),
            chatOutbox: queue,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Friends group');
      await tester.tap(find.text('Actual friend'));
      await tester.pump();
      await tester.tap(find.text('创建（1）'));
      await tester.pump();
      expect(createRequest!['members'], ['actual-peer']);
      expect(find.byType(DirectChatPage), findsNothing);
      created.complete({'groupId': 'actual-group'});
      await tester.pumpAndSettle();
      expect(find.byType(DirectChatPage), findsOneWidget);
      expect(find.text('A6 卡座见'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'Group hello');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(sendRequest!['groupId'], 'actual-group');
      expect(sendRequest!.containsKey('recipient'), false);
      expect(queue.rows, isEmpty);
      expect(find.text('Group hello'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
