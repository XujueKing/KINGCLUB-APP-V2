import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_join_review_page.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_member_avatar.dart';
import 'package:kingclub/src/features/contacts/presentation/public_member_page.dart';

void main() {
  const groupId = '11111111-1111-4111-8111-111111111111';
  const applicationId = '22222222-2222-4222-8222-222222222222';
  testWidgets('only relevant membership notifications refresh review', (
    tester,
  ) async {
    final events = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(events.close);
    var reads = 0;
    final repo = GroupChatRepository(
      MessagingRepository(
        account: 'me',
        call: (_, _) async {
          reads++;
          return {
            'groupId': groupId,
            'membershipVersion': 1,
            'items': [],
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
    events.add({
      'eventType': 'chat.group.changed',
      'data': {'groupId': 'other'},
    });
    await tester.pumpAndSettle();
    expect(reads, 1);
    events.add({
      'eventType': 'chat.group.changed',
      'data': {'groupId': groupId},
    });
    await tester.pumpAndSettle();
    expect(reads, 2);
    events.add({'eventType': 'connection.ready'});
    await tester.pumpAndSettle();
    expect(reads, 3);
    events.add({'eventType': 'chat.group.changed'});
    await tester.pumpAndSettle();
    expect(reads, 4);
  });
  testWidgets('applicant avatar opens authorized visitor profile', (
    tester,
  ) async {
    final repo = GroupChatRepository(
      MessagingRepository(
        account: 'me',
        call: (id, p) async {
          if (id == 'K260913000612') {
            expect(p['peer'], 'peer');
            return {'nickname': 'Applicant name'};
          }
          if (id != 'K260914000659') return <String, dynamic>{};
          return {
            'groupId': groupId,
            'membershipVersion': 4,
            'nextCursor': null,
            'items': [
              {
                'applicationId': applicationId,
                'applicant': 'peer',
                'note': 'Hello',
                'status': 'pending',
              },
            ],
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
    final avatar = tester.widget<ChatMemberAvatar>(
      find.byType(ChatMemberAvatar),
    );
    expect(avatar.account, 'peer');
    expect((await avatar.profile)['nickname'], 'Applicant name');
    await tester.tap(find.byType(ChatMemberAvatar));
    await tester.pumpAndSettle();
    final page = tester.widget<PublicMemberPage>(find.byType(PublicMemberPage));
    expect(page.account, 'peer');
    expect(page.repository, same(repo.messaging));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late applicant profile cannot restore a revoked review list', (
    tester,
  ) async {
    final profile = Completer<Map<String, dynamic>>();
    final events = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(events.close);
    var denied = false;
    final repo = GroupChatRepository(
      MessagingRepository(
        account: 'me',
        call: (id, p) async {
          if (id == 'K260913000612') return profile.future;
          if (denied) throw StateError('permission revoked');
          return {
            'groupId': groupId,
            'membershipVersion': 4,
            'nextCursor': null,
            'items': [
              {
                'applicationId': applicationId,
                'applicant': 'peer',
                'note': 'Private note',
                'status': 'pending',
              },
            ],
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
    expect(find.text('申请人'), findsOneWidget);
    expect(find.text('peer'), findsNothing);
    denied = true;
    events.add({'eventType': 'chat.group.changed'});
    await tester.pumpAndSettle();
    profile.complete({'nickname': 'Old private name'});
    await tester.pumpAndSettle();
    expect(find.text('Old private name'), findsNothing);
    expect(find.byType(ChatMemberAvatar), findsNothing);
    expect(find.text('Private note'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
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
              if (id == 'K260913000612') return {'nickname': 'Applicant name'};
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
        expect(find.text('Applicant name'), findsOneWidget);
        expect(find.text('peer'), findsNothing);
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
            if (id == 'K260913000612') return {'nickname': 'Applicant name'};
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
