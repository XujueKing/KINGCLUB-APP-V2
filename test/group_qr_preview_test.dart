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
}
