import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_qr_preview_page.dart';

void main() {
  const code = 'KC:G:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  Map<String, dynamic> response(bool member) => {
    'groupId': '11111111-1111-4111-8111-111111111111',
    'groupName': 'Synthetic group',
    'memberCount': 2,
    'alreadyMember': member,
    'expiresAt': DateTime.now()
        .add(const Duration(minutes: 5))
        .toIso8601String(),
  };
  for (final member in [false, true]) {
    testWidgets(
      'preview member=$member does not request admission or history',
      (tester) async {
        final calls = <String>[];
        final repo = GroupChatRepository(
          MessagingRepository(
            account: 'me',
            call: (id, p) async {
              calls.add(id);
              expectSync(p, {'code': code});
              return response(member);
            },
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: GroupQrPreviewPage(code: code, repository: repo),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, ['K260914000657']);
        expect(find.text('Synthetic group'), findsOneWidget);
        expect(find.text('进入群聊'), member ? findsOneWidget : findsNothing);
        SecureSessionStore.changes.add(null);
        await tester.pumpAndSettle();
        expect(find.text('Synthetic group'), findsNothing);
        expect(find.text('进入群聊'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('late response after logout cannot restore preview', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    final repo = GroupChatRepository(
      MessagingRepository(account: 'me', call: (id, p) => pending.future),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GroupQrPreviewPage(code: code, repository: repo),
      ),
    );
    await tester.pump();
    SecureSessionStore.changes.add(null);
    await tester.pump();
    pending.complete(response(true));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic group'), findsNothing);
    expect(find.text('登录状态已变化'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('malformed group code does not call server', (tester) async {
    var calls = 0;
    final repo = GroupChatRepository(
      MessagingRepository(
        account: 'me',
        call: (id, p) async {
          calls++;
          return response(true);
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GroupQrPreviewPage(code: 'KC:G:bad', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('进入群聊'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'expiry hides entry and background reauthorizes before showing data',
    (tester) async {
      var calls = 0;
      Completer<Map<String, dynamic>>? pending;
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, p) async {
            calls++;
            if (pending != null) {
              return pending.future;
            }
            return {
              ...response(true),
              'expiresAt': DateTime.now()
                  .add(const Duration(seconds: 2))
                  .toIso8601String(),
            };
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupQrPreviewPage(code: code, repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('进入群聊'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('进入群聊'), findsNothing);
      expect(find.text('Synthetic group'), findsNothing);
      expect(find.text('二维码已过期，请重新扫描'), findsOneWidget);
      pending = Completer();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 2);
      expect(find.text('进入群聊'), findsNothing);
      pending.complete(response(false));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic group'), findsOneWidget);
      expect(find.text('进入群聊'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'group change removes old preview and ignores superseded response',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      final pending = <Completer<Map<String, dynamic>>>[];
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, p) {
            final call = Completer<Map<String, dynamic>>();
            pending.add(call);
            return call.future;
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupQrPreviewPage(
            code: code,
            repository: repo,
            events: events.stream,
          ),
        ),
      );
      await tester.pump();
      pending[0].complete(response(true));
      await tester.pumpAndSettle();
      expect(find.text('进入群聊'), findsOneWidget);
      events.add({'eventType': 'chat.group.changed'});
      await tester.pumpAndSettle();
      expect(find.text('Synthetic group'), findsNothing);
      events.add({'eventType': 'connection.ready'});
      await tester.pumpAndSettle();
      expect(pending.length, 3);
      pending[1].complete(response(true));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic group'), findsNothing);
      pending[2].completeError(StateError('revoked'));
      await tester.pumpAndSettle();
      expect(find.text('进入群聊'), findsNothing);
      expect(find.text('二维码已失效或无法读取，请重新扫描'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await events.close();
    },
  );
}
