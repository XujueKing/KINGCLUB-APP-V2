import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';

void main() {
  for (final systemDay in [null, 9, 11, 13]) {
    testWidgets('system inbox merges by timestamp day=$systemDay', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      final repo = MessagingRepository(
        account: 'me',
        call: (api, args) async {
          if (api != 'K260913000607') return {};
          return {
            'items': [
              for (final day in [12, 10])
                {
                  'kind': 'direct',
                  'peer': 'peer-$day',
                  'nickname': 'Peer $day',
                  'preview': 'Message',
                  'messageDate': '2026-09-${day}T12:00:00Z',
                  'lastSequence': 1,
                  'unreadCount': 0,
                  'pinned': false,
                  'muted': false,
                },
            ],
            'hasMore': false,
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationsPage(
              active: true,
              realData: true,
              repository: repo,
              systemMessageDate: systemDay == null
                  ? null
                  : DateTime.utc(2026, 9, systemDay, 12),
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
      final systemY = tester.getTopLeft(find.text('KINGCLUB')).dy;
      for (final day in [12, 10]) {
        final peerY = tester.getTopLeft(find.text('Peer $day')).dy;
        expect(
          systemY,
          systemDay != null && systemDay > day
              ? lessThan(peerY)
              : greaterThan(peerY),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
