import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_join_receipt_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_join_request_page.dart';

void main() {
  const group = '11111111-1111-4111-8111-111111111111';
  const application = '22222222-2222-4222-8222-222222222222';
  const code = 'KC:G:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'receipts survive recreation, isolate accounts, and reject stale removal',
    () async {
      await GroupJoinReceiptStore('a').save(group, application);
      expect(await GroupJoinReceiptStore('a').application(group), application);
      expect(await GroupJoinReceiptStore('b').application(group), null);
      await GroupJoinReceiptStore('a').forget(group, 'old');
      expect(await GroupJoinReceiptStore('a').application(group), application);
      await GroupJoinReceiptStore('a').forget(group, application);
      expect(await GroupJoinReceiptStore('a').application(group), null);
    },
  );

  testWidgets(
    'reopening restores receipt and queries without resubmitting; rejection allows explicit retry',
    (tester) async {
      var submits = 0;
      var status = 'pending';
      final messaging = MessagingRepository(
        account: 'a',
        call: (id, params) async {
          if (id == 'K260914000658') {
            submits++;
            return {
              'groupId': group,
              'applicationId': application,
              'status': 'pending',
              'changed': true,
            };
          }
          if (id == 'K260913000619') throw StateError('not a member');
          expect(id, 'K260916000684');
          expect(params, {'groupId': group, 'applicationId': application});
          return {
            'groupId': group,
            'applicationId': application,
            'status': status,
            'changed': false,
          };
        },
      );
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: GroupJoinRequestPage(
              groupId: group,
              groupName: 'Test group',
              code: code,
              repository: GroupChatRepository(messaging),
              events: const Stream<Map<String, dynamic>>.empty(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open();
      await tester.enterText(find.byType(TextField), 'private note');
      await tester.tap(find.text('提交申请'));
      await tester.pumpAndSettle();
      expect(submits, 1);
      final stored = (await const FlutterSecureStorage().readAll()).values
          .join();
      expect(stored, isNot(contains(code)));
      expect(stored, isNot(contains('private note')));
      await tester.pumpWidget(const SizedBox());
      await open();
      expect(find.text('申请已提交，等待群主或管理员审核'), findsOneWidget);
      expect(find.text('提交申请'), findsNothing);
      expect(find.text('进入群聊'), findsNothing);
      expect(submits, 1);
      status = 'rejected';
      await tester.tap(find.text('刷新入群状态'));
      await tester.pumpAndSettle();
      expect(find.text('申请未通过'), findsOneWidget);
      await tester.tap(find.text('重新申请'));
      await tester.pumpAndSettle();
      expect(find.text('提交申请'), findsOneWidget);
      expect(submits, 1);
      await tester.tap(find.text('提交申请'));
      await tester.pumpAndSettle();
      expect(submits, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'offline restored receipt never implies pending, rejection, or membership',
    (tester) async {
      await GroupJoinReceiptStore('a').save(group, application);
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: GroupJoinRequestPage(
            groupId: group,
            groupName: 'Test group',
            code: code,
            repository: GroupChatRepository(
              MessagingRepository(
                account: 'a',
                call: (id, _) async {
                  calls.add(id);
                  throw StateError('offline');
                },
              ),
            ),
            events: const Stream<Map<String, dynamic>>.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, ['K260913000619', 'K260916000684']);
      expect(find.text('已提交过入群申请，请刷新查看当前状态'), findsOneWidget);
      expect(find.text('提交申请'), findsNothing);
      expect(find.text('进入群聊'), findsNothing);
      expect(find.text('重新申请'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
