import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_announcement_page.dart';

void main() {
  for (final role in ['member', 'admin']) {
    testWidgets('announcement reads and respects role=$role', (tester) async {
      var text = '原公告', version = 2, fail = true;
      var denied = false;
      Map<String, dynamic>? published;
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, p) async {
            if (id == 'K260913000619') {
              return {
                'ownerAccount': 'leader',
                'membershipVersion': 4,
                'announcementVersion': version,
                'announcementText': text,
                'members': [
                  {'account': 'me', 'role': role},
                ],
              };
            }
            if (id == 'K260914000655') {
              published = p;
              if (denied)
                throw const AuthFailure('CHAT_GROUP_ACCESS_DENIED', '无群权限');
              if (fail) throw StateError('保存失败');
              text = p['text'] as String;
              version++;
              return {
                'groupId': 'group',
                'text': text,
                'version': version,
                'changed': true,
              };
            }
            throw StateError(id);
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupAnnouncementPage(groupId: 'group', repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('原公告'), findsOneWidget);
      if (role == 'member') {
        expect(find.text('编辑'), findsNothing);
        expect(find.byType(TextField), findsNothing);
      } else {
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        final input = find.byKey(const ValueKey('group-announcement-input'));
        await tester.enterText(input, ' 新公告 ');
        await tester.tap(find.text('发布'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(input).controller!.text, ' 新公告 ');
        expect(published, {
          'groupId': 'group',
          'text': '新公告',
          'expectedVersion': 2,
          'membershipVersion': 4,
        });
        fail = false;
        await tester.tap(find.text('发布'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.text('新公告'), findsOneWidget);
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        await tester.enterText(input, '');
        await tester.tap(find.text('发布'));
        await tester.pumpAndSettle();
        expect(find.text('暂无群公告'), findsOneWidget);
        expect(published!['expectedVersion'], 3);
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        await tester.enterText(input, 'Private draft');
        denied = true;
        await tester.tap(find.text('发布'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Private draft'), findsNothing);
        expect(find.text('编辑'), findsNothing);
      }
      SecureSessionStore.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('原公告'), findsNothing);
      expect(find.text('编辑'), findsNothing);
      expect(find.text('登录状态已变化'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
