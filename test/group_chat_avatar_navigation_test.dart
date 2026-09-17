import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_member_avatar.dart';
import 'package:kingclub/src/features/contacts/presentation/public_member_page.dart';

import 'group_chat_controller_test.dart' show Queue, message, history;

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final pending in [false, true]) {
    testWidgets('group avatar uses actual sender pending=$pending', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final queue = Queue();
      final sender = pending ? 'me' : 'other-member';
      if (pending) {
        await queue.put({...message('pending'), 'status': 'queued'});
      }
      final profiles = <String>[];
      final repo = MessagingRepository(
        account: 'me',
        call: (api, args) async {
          if (api == 'K260913000612') {
            profiles.add(args['peer'] as String);
            return {'nickname': 'Member profile'};
          }
          if (api == 'K260913000619') return {'members': []};
          if (api == 'K260913000621') {
            if (pending) throw const AuthFailure('NETWORK_ERROR', 'offline');
            return history([
              {...message('received'), 'sender': sender},
            ]);
          }
          return {};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DirectChatPage(
            groupId: 'group',
            repository: repo,
            chatOutbox: queue,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final finder = find.byType(ChatMemberAvatar);
      expect(finder, findsOneWidget);
      expect(tester.widget<ChatMemberAvatar>(finder).account, sender);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      final profile = tester.widget<PublicMemberPage>(
        find.byType(PublicMemberPage),
      );
      expect(profile.account, sender);
      expect(profile.repository, same(repo));
      expect(profiles, contains(sender));
      expect(profiles, isNot(contains('group')));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
