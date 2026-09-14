import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_qr_page.dart';

void main() {
  testWidgets(
    'real group QR hides on background and discards late session response',
    (tester) async {
      var requests = 0;
      Completer<Map<String, dynamic>>? pending;
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, p) async {
            expectSync(p, {'groupId': 'group'});
            if (id == 'K260913000619') {
              return {'groupName': '测试群'};
            }
            expectSync(id, 'K260914000656');
            requests++;
            if (pending != null) {
              return pending.future;
            }
            return {
              'groupId': 'group',
              'code': 'KC:G:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
              'ttlSeconds': 600,
            };
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupQrPage(groupId: 'group', repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('测试群'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byType(QrImageView), findsNothing);
      pending = Completer();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(requests, 2);
      SecureSessionStore.changes.add(null);
      await tester.pump();
      pending.complete({
        'groupId': 'group',
        'code': 'KC:G:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
        'ttlSeconds': 600,
      });
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('测试群'), findsNothing);
      expect(find.text('登录状态已变化'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('invalid QR acknowledgement never renders and can retry', (
    tester,
  ) async {
    var valid = false;
    final repo = GroupChatRepository(
      MessagingRepository(
        account: 'me',
        call: (id, p) async {
          if (id == 'K260913000619') {
            return {'groupName': '测试群'};
          }
          return {
            'groupId': valid ? 'group' : 'another',
            'code': 'KC:G:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
            'ttlSeconds': 600,
          };
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GroupQrPage(groupId: 'group', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    valid = true;
    await tester.tap(find.text('刷新二维码'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
