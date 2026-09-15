import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_join_request_page.dart';

void main() {
  const groupId = '11111111-1111-4111-8111-111111111111';
  const code = 'KC:G:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('own status rejects mismatched or non-read-only receipts', () async {
    const applicationId = '22222222-2222-4222-8222-222222222222';
    for (final changes in [
      {'groupId': 'other'},
      {'applicationId': 'other'},
      {'changed': true},
      {'status': 'unknown'},
    ]) {
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (_, _) async => {
            'groupId': groupId,
            'applicationId': applicationId,
            'changed': false,
            'status': 'accepted',
            ...changes,
          },
        ),
      );
      await expectLater(
        repo.ownApplicationStatus(
          groupId: groupId,
          applicationId: applicationId,
        ),
        throwsFormatException,
      );
    }
  });
  testWidgets('own status updates without resubmitting or granting entry', (
    tester,
  ) async {
    const applicationId = '22222222-2222-4222-8222-222222222222';
    final events = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(events.close);
    var status = 'pending', submits = 0;
    Completer<Map<String, dynamic>>? delayed;
    final repo = GroupChatRepository(
      MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260914000658') {
            submits++;
            return {
              'groupId': groupId,
              'applicationId': applicationId,
              'status': 'pending',
              'changed': true,
            };
          }
          if (id == 'K260913000619') throw StateError('not a current member');
          expect(id, 'K260916000684');
          expect(params, {'groupId': groupId, 'applicationId': applicationId});
          return delayed?.future ??
              Future.value({
                'groupId': groupId,
                'applicationId': applicationId,
                'status': status,
                'changed': false,
              });
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GroupJoinRequestPage(
          groupId: groupId,
          groupName: 'Test group',
          code: code,
          repository: repo,
          events: events.stream,
        ),
      ),
    );
    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();
    for (final entry in {
      'rejected': '申请未通过',
      'expired': '申请已过期，请重新扫描',
      'canceled': '申请已取消',
      'accepted': '申请已通过',
    }.entries) {
      status = entry.key;
      events.add({'eventType': 'chat.group.changed'});
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('进入群聊'), findsNothing);
      expect(submits, 1);
    }
    delayed = Completer<Map<String, dynamic>>();
    events.add({'eventType': 'chat.group.changed'});
    await tester.pumpAndSettle();
    SecureSessionStore.changes.add(null);
    await tester.pump();
    delayed.complete({
      'groupId': groupId,
      'applicationId': applicationId,
      'status': 'accepted',
      'changed': false,
    });
    await tester.pumpAndSettle();
    expect(find.text('申请已通过'), findsNothing);
    expect(find.text('进入群聊'), findsNothing);
    expect(find.text('登录状态已变化'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'approval event rechecks membership and session loss rejects late response',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      addTearDown(events.close);
      Completer<Map<String, dynamic>>? pending;
      var lookups = 0;
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, p) async {
            if (id == 'K260914000658') {
              return {
                'groupId': groupId,
                'applicationId': '22222222-2222-4222-8222-222222222222',
                'status': 'pending',
                'changed': true,
              };
            }
            expect(id, 'K260913000619');
            lookups++;
            return pending?.future ??
                Future.value({
                  'groupId': groupId,
                  'members': [
                    {'account': 'me'},
                  ],
                });
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupJoinRequestPage(
            groupId: groupId,
            groupName: 'Test group',
            code: code,
            repository: repo,
            events: events.stream,
          ),
        ),
      );
      await tester.tap(find.text('提交申请'));
      await tester.pumpAndSettle();
      expect(find.text('进入群聊'), findsNothing);
      events.add({'eventType': 'chat.group.changed'});
      await tester.pumpAndSettle();
      expect(lookups, 1);
      expect(find.text('进入群聊'), findsOneWidget);
      pending = Completer<Map<String, dynamic>>();
      events.add({'eventType': 'chat.group.changed'});
      await tester.pumpAndSettle();
      expect(find.text('进入群聊'), findsNothing);
      SecureSessionStore.changes.add(null);
      await tester.pump();
      pending.complete({
        'groupId': groupId,
        'members': [
          {'account': 'me'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('进入群聊'), findsNothing);
      expect(find.text('登录状态已变化'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'approval arriving before submit response is checked without resubmission',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      addTearDown(events.close);
      final submitted = Completer<Map<String, dynamic>>();
      var sends = 0, checks = 0;
      var member = false;
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, p) async {
            if (id == 'K260914000658') {
              sends++;
              return submitted.future;
            }
            if (id == 'K260916000684') return {}; // Older server fallback.
            expect(id, 'K260913000619');
            checks++;
            return {
              'groupId': groupId,
              'members': member
                  ? [
                      {'account': 'me'},
                    ]
                  : [],
            };
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupJoinRequestPage(
            groupId: groupId,
            groupName: 'Test group',
            code: code,
            repository: repo,
            events: events.stream,
          ),
        ),
      );
      await tester.tap(find.text('提交申请'));
      await tester.pump();
      events.add({'eventType': 'chat.group.changed'});
      await tester.pump();
      submitted.complete({
        'groupId': groupId,
        'applicationId': '22222222-2222-4222-8222-222222222222',
        'status': 'pending',
        'changed': true,
      });
      await tester.pumpAndSettle();
      expect(checks, 1);
      expect(find.text('进入群聊'), findsNothing);
      member = true;
      await tester.tap(find.text('刷新入群状态'));
      await tester.pumpAndSettle();
      expect(sends, 1);
      expect(checks, 2);
      expect(find.text('进入群聊'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'application retries exact frozen note and only displays acknowledged pending',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, p) async {
            expectSync(id, 'K260914000658');
            calls.add(Map.from(p));
            if (calls.length == 1) {
              throw StateError('offline');
            }
            return {
              'groupId': groupId,
              'applicationId': '22222222-2222-4222-8222-222222222222',
              'status': 'pending',
              'changed': true,
            };
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupJoinRequestPage(
            groupId: groupId,
            groupName: 'Test group',
            code: code,
            repository: repo,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), ' Hello ');
      await tester.tap(find.text('提交申请'));
      await tester.pumpAndSettle();
      expect(find.text('申请已提交，等待群主或管理员审核'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
      await tester.tap(find.text('重试申请'));
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      expect(calls[0], calls[1]);
      expect(calls[1]['note'], 'Hello');
      expect(find.text('申请已提交，等待群主或管理员审核'), findsOneWidget);
      expect(find.text('进入群聊'), findsNothing);
      SecureSessionStore.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Test group'), findsNothing);
      expect(find.text('申请已提交，等待群主或管理员审核'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('invalid acknowledgement retains identity across repository recreation without storing QR', () async {
    final calls = <Map<String, dynamic>>[];
    var valid = false;
    final messaging = MessagingRepository(
      account: 'me',
      call: (id, p) async {
        calls.add(Map.from(p));
        return {
          'groupId': valid ? groupId : 'other',
          'applicationId': '22222222-2222-4222-8222-222222222222',
          'status': 'pending',
          'changed': false,
        };
      },
    );
    await expectLater(
      GroupChatRepository(messaging)
          .applyToGroup(groupId: groupId, code: code, note: 'hello'),
      throwsFormatException,
    );
    final stored = (await const FlutterSecureStorage().readAll()).values.join();
    expect(stored, isNot(contains(code)));
    expect(stored, isNot(contains('hello')));
    valid = true;
    await GroupChatRepository(messaging)
        .applyToGroup(groupId: groupId, code: code, note: 'hello');
    expect(calls[0]['requestId'], calls[1]['requestId']);
  });
}
