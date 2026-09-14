
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, ack, history;

void main() {
  testWidgets(
    'session renewal restores chat; account switch does not disclose old chat',
    (tester) async {
      tester.view.physicalSize = const Size(393, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({});
      var opened = 0;
      MessagingRepository repo(String text) => MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000604')
            return history([
              ack({'clientMessageId': 'one', 'text': text}),
            ]);
          return {};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DirectChatPage(
            peerAccount: 'peer',
            repository: repo('Before renewal'),
            chatOutbox: MemoryOutbox(),
            openRepository: () async {
              opened++;
              return repo('After renewal');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Before renewal'), findsOneWidget);
      expect(find.text('好友关系已结束，历史记录仅可查看'), findsNothing);
      await SecureSessionStore().saveSession({
        'sessionId': 'new',
        'account': {'userAccount': 'me'},
      });
      for (
        var i = 0;
        i < 30 && find.text('After renewal').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(find.text('After renewal'), findsOneWidget);
      expect(find.text('当前不可发送消息'), findsNothing);
      expect(opened, 1);
      await SecureSessionStore().saveSession({
        'sessionId': 'other',
        'account': {'userAccount': 'other'},
      });
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('After renewal'), findsNothing);
      expect(find.text('登录状态已变化，请重新进入会话'), findsOneWidget);
      expect(find.text('好友关系已结束，历史记录仅可查看'), findsNothing);
      expect(opened, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
