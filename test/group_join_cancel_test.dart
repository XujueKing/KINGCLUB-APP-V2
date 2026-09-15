import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_join_receipt_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_join_request_page.dart';

void main() {
  const group = '11111111-1111-4111-8111-111111111111';
  const application = '22222222-2222-4222-8222-222222222222';
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'cancel acknowledgement must match identity and terminal status',
    () async {
      for (final changes in [
        {'groupId': 'other'},
        {'applicationId': 'other'},
        {'status': 'accepted'},
        {'changed': null},
      ]) {
        final repo = GroupChatRepository(
          MessagingRepository(
            account: 'a',
            call: (_, _) async => {
              'groupId': group,
              'applicationId': application,
              'status': 'canceled',
              'changed': true,
              ...changes,
            },
          ),
        );
        await expectLater(
          repo.cancelApplication(groupId: group, applicationId: application),
          throwsFormatException,
        );
      }
    },
  );
  for (final outcome in [
    'success',
    'failure',
    'accepted',
    'session',
    'resume',
  ]) {
    testWidgets('withdrawal confirmation and $outcome result', (tester) async {
      await GroupJoinReceiptStore('a').save(group, application);
      var status = 'pending', calls = 0;
      final pending = Completer<Map<String, dynamic>>();
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'a',
          call: (method, params) async {
            if (method == 'K260913000619') {
              if (status == 'accepted') {
                return {
                  'groupId': group,
                  'members': [
                    {'account': 'a'},
                  ],
                };
              }
              throw StateError('not a member');
            }
            if (method == 'K260916000684') {
              return {
                'groupId': group,
                'applicationId': application,
                'status': status,
                'changed': false,
              };
            }
            expect(method, 'K260916000685');
            expect(params, {'groupId': group, 'applicationId': application});
            calls++;
            if (outcome == 'failure') {
              throw const AuthFailure('NETWORK_ERROR', 'offline');
            }
            if (outcome == 'accepted') {
              status = 'accepted';
              throw const AuthFailure(
                'CHAT_GROUP_JOIN_RESOLVED',
                'already accepted',
              );
            }
            if (outcome == 'session' || outcome == 'resume') {
              return pending.future;
            }
            status = 'canceled';
            return {
              'groupId': group,
              'applicationId': application,
              'status': status,
              'changed': true,
            };
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupJoinRequestPage(
            groupId: group,
            groupName: 'Test group',
            code: 'KC:G:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
            repository: repo,
            events: const Stream.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤回申请'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('保留申请'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('撤回申请'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认撤回'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      if (outcome == 'resume') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        status = 'canceled';
        pending.complete({
          'groupId': group,
          'applicationId': application,
          'status': status,
          'changed': true,
        });
        await tester.pumpAndSettle();
        expect(find.text('申请已取消'), findsOneWidget);
        expect(find.text('撤回申请'), findsNothing);
        expect(calls, 1);
      } else if (outcome == 'session') {
        SecureSessionStore.changes.add(null);
        await tester.pump();
        pending.complete({
          'groupId': group,
          'applicationId': application,
          'status': 'canceled',
          'changed': true,
        });
        await tester.pumpAndSettle();
        expect(find.text('申请已取消'), findsNothing);
      } else if (outcome == 'accepted') {
        expect(find.text('进入群聊'), findsOneWidget);
        expect(find.text('申请已取消'), findsNothing);
      } else if (outcome == 'failure') {
        expect(find.text('撤回结果未确认，请刷新后重试'), findsOneWidget);
        expect(find.text('撤回申请'), findsOneWidget);
      } else {
        expect(find.text('申请已取消'), findsOneWidget);
        expect(find.text('重新申请'), findsOneWidget);
        expect(
          await GroupJoinReceiptStore('a').application(group),
          application,
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
