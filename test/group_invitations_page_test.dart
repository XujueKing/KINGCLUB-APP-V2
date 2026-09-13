import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_invitations_page.dart';

void main() {
  testWidgets('accept requires confirmation and server acknowledgement', (
    tester,
  ) async {
    var status = 'pending';
    final decisions = <Map<String, dynamic>>[];
    final ack = Completer<Map<String, dynamic>>();
    final repository = GroupChatRepository(
      MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000629')
            return {
              'items': [
                {
                  'invitationId': 'invite',
                  'groupId': 'group',
                  'groupName': 'Fixture group',
                  'inviter': 'friend',
                  'status': status,
                },
              ],
              'nextCursor': null,
            };
          expect(id, 'K260913000630');
          decisions.add(params);
          return ack.future;
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GroupInvitationsPage(
          repository: repository,
          events: const Stream.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入'));
    await tester.pumpAndSettle();
    expect(decisions, isEmpty);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(decisions, isEmpty);
    await tester.tap(find.text('加入'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '加入').last);
    await tester.pumpAndSettle();
    expect(decisions.single, {
      'groupId': 'group',
      'invitationId': 'invite',
      'action': 'accept',
    });
    expect(find.text('查看群聊'), findsNothing);
    status = 'accepted';
    ack.complete({
      'groupId': 'group',
      'invitationId': 'invite',
      'status': status,
      'changed': true,
    });
    await tester.pumpAndSettle();
    expect(find.text('查看群聊'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'session change clears invitations and rejects late inbox result',
    (tester) async {
      final result = Completer<Map<String, dynamic>>();
      final repository = GroupChatRepository(
        MessagingRepository(account: 'me', call: (_, _) => result.future),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupInvitationsPage(
            repository: repository,
            events: const Stream.empty(),
          ),
        ),
      );
      await tester.pump();
      SecureSessionStore.changes.add(null);
      await tester.pump();
      result.complete({
        'items': [
          {
            'groupName': 'Private invite',
            'invitationId': 'i',
            'groupId': 'g',
            'inviter': 'friend',
            'status': 'pending',
          },
        ],
        'nextCursor': null,
      });
      await tester.pumpAndSettle();
      expect(find.text('Private invite'), findsNothing);
      expect(find.text('登录状态已变化，请重新进入'), findsOneWidget);
    },
  );
}
