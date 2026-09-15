import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/contacts/presentation/contacts_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';

void main() {
  for (final contacts in [false, true]) {
    for (final entry in [
      (const AuthFailure('SESSION_EXPIRED', 'Session expired'), '登录已失效，请重新登录'),
      (const AuthFailure('NETWORK_ERROR', 'offline'), '网络不可用，请稍后重试'),
      (const FormatException('private internal detail'), '暂时无法更新，请稍后重试'),
    ]) {
      testWidgets(
        'refresh error is classified: contacts=$contacts ${entry.$2}',
        (tester) async {
          FlutterSecureStorage.setMockInitialValues({});
          tester.view.physicalSize = const Size(393, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = MessagingRepository(
            account: 'me',
            call: (_, _) async => throw entry.$1,
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: contacts
                    ? ContactsPage(
                        active: true,
                        realData: true,
                        repository: repository,
                        onIntent: (_) {},
                      )
                    : ConversationsPage(
                        active: true,
                        realData: true,
                        repository: repository,
                        systemUnreadCount: 0,
                        initialFriendUnreadCount: 0,
                        onFriendUnreadChanged: (_) {},
                        onOpenContacts: () {},
                        onAddFriend: () {},
                        onOpenSystemNotifications: () {},
                        onOpenDirectChat: () {},
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(entry.$2), findsOneWidget);
          expect(find.text('Session expired'), findsNothing);
          expect(find.text('private internal detail'), findsNothing);
          expect(find.text('网络不可用，已保留最近会话'), findsNothing);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
