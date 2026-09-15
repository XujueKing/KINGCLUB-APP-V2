import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_call_page.dart';

void main() {
  testWidgets(
    'member selection reads real repository and retains start identity on retry',
    (tester) async {
      final starts = <Map<String, dynamic>>[];
      final repository = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, input) async {
            if (id == 'K260915000678') {
              starts.add(Map<String, dynamic>.from(input));
              throw const AuthFailure('UNAVAILABLE', '暂不可用');
            }
            return {
              'members': [
                {'account': 'me', 'nickname': '我'},
                {'account': 'friend', 'nickname': '测试朋友'},
              ],
            };
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupCallPage(
            repository: repository,
            groupId: '00000000-0000-4000-8000-000000000001',
            media: CallMedia.audio,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(starts, isEmpty);
      expect(find.text('测试朋友'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('发起通话'));
      await tester.pumpAndSettle();
      expect(find.text('暂不可用'), findsOneWidget);
      expect(starts.single['invitees'], ['friend']);
      await tester.tap(find.text('发起通话'));
      await tester.pumpAndSettle();
      expect(starts.length, 2);
      expect(starts.first['requestId'], starts.last['requestId']);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
