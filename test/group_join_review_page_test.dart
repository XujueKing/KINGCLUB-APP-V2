import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_join_review_page.dart';

void main() {
  const groupId = '11111111-1111-4111-8111-111111111111';
  const applicationId = '22222222-2222-4222-8222-222222222222';
  for (final accept in [true, false]) {
    testWidgets(
      'review accept=$accept confirms, retries and reloads server status',
      (tester) async {
        var status = 'pending', fail = true;
        final writes = <Map<String, dynamic>>[];
        final repo = GroupChatRepository(
          MessagingRepository(
            account: 'me',
            call: (id, p) async {
              if (id == 'K260914000659') {
                return {
                  'groupId': groupId,
                  'membershipVersion': 4,
                  'items': [
                    {
                      'applicationId': applicationId,
                      'applicant': 'peer',
                      'note': 'Private note',
                      'status': status,
                    },
                  ],
                  'nextCursor': null,
                };
              }
              expectSync(id, 'K260914000660');
              writes.add(Map.from(p));
              if (fail) {
                throw StateError('offline');
              }
              status = accept ? 'accepted' : 'rejected';
              return {
                'groupId': groupId,
                'applicationId': applicationId,
                'status': status,
                'changed': true,
              };
            },
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: GroupJoinReviewPage(groupId: groupId, repository: repo),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(accept ? '同意' : '拒绝'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(writes, isEmpty);
        for (final retry in [false, true]) {
          fail = !retry;
          await tester.tap(find.text(accept ? '同意' : '拒绝'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('确认'));
          await tester.pumpAndSettle();
        }
        expect(writes.length, 2);
        expect(writes[0], writes[1]);
        expect(writes[1], {
          'groupId': groupId,
          'applicationId': applicationId,
          'action': accept ? 'accept' : 'reject',
          'membershipVersion': 4,
        });
        expect(find.text(accept ? '已同意' : '已拒绝'), findsOneWidget);
        SecureSessionStore.changes.add(null);
        await tester.pumpAndSettle();
        expect(find.text('Private note'), findsNothing);
        expect(find.text('peer'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'permission refresh clears notes and stale confirmation cannot submit',
    (tester) async {
      var denied = false, writes = 0;
      final events = StreamController<Map<String, dynamic>>.broadcast();
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, p) async {
            if (id == 'K260914000660') {
              writes++;
              throw StateError('must not submit');
            }
            if (denied) {
              throw StateError('permission revoked');
            }
            return {
              'groupId': groupId,
              'membershipVersion': 4,
              'items': [
                {
                  'applicationId': applicationId,
                  'applicant': 'peer',
                  'note': 'Private note',
                  'status': 'pending',
                },
              ],
              'nextCursor': null,
            };
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupJoinReviewPage(
            groupId: groupId,
            repository: repo,
            events: events.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('同意'));
      await tester.pumpAndSettle();
      denied = true;
      events.add({'eventType': 'chat.group.changed'});
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.text('Private note'), findsNothing);
      expect(find.text('同意'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await events.close();
    },
  );
}
